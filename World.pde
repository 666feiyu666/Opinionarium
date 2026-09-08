class World {
  ArrayList<Agent> agents = new ArrayList<Agent>();
  ArrayList<Connection> connections = new ArrayList<Connection>();
  ArrayList<Message> messages = new ArrayList<Message>();

  Agent selectedAgent;
  Agent currentSpeaker;

  boolean paused = false;
  boolean pauseAfterCurrentCycle = false;
  boolean showFullNetwork = false;

  float speedMultiplier = 1.0;
  float timeUntilNextPost = 0.7;
  float cycleSettleTime = 0;
  int cycleCount = 0;
  int resetCount = 0;
  int previousMillis;

  final int AGENT_COUNT = 30;
  final float PANEL_WIDTH = 260;
  final float FOLLOW_DISTANCE = 0.45;
  final float UNFOLLOW_DISTANCE = 0.95;
  final float FOLLOW_PROBABILITY = 0.55;
  final float UNFOLLOW_PROBABILITY = 0.45;
  final float DISCOVERY_PROBABILITY = 0.60;

  void reset() {
    agents.clear();
    connections.clear();
    messages.clear();

    selectedAgent = null;
    currentSpeaker = null;
    paused = false;
    pauseAfterCurrentCycle = false;
    showFullNetwork = false;
    speedMultiplier = 1.0;
    timeUntilNextPost = 0.7;
    cycleSettleTime = 0;
    cycleCount = 0;

    randomSeed(4700 + resetCount);
    resetCount++;

    createAgents();
    createConnections();
    refreshAllFollowerCounts(false);
    previousMillis = millis();
  }

  void createAgents() {
    int leaderId = int(random(AGENT_COUNT));

    for (int id = 0; id < AGENT_COUNT; id++) {
      PVector position = findOpenPosition();
      float opinion = random(-1, 1);
      float activity = random(0.35, 1.0);
      boolean leader = id == leaderId;

      agents.add(new Agent(id, position, opinion, activity, leader));
    }
  }

  PVector findOpenPosition() {
    float minX = 70;
    float maxX = width - PANEL_WIDTH - 50;
    float minY = 105;
    float maxY = height - 55;

    for (int attempt = 0; attempt < 200; attempt++) {
      PVector candidate = new PVector(random(minX, maxX), random(minY, maxY));
      boolean open = true;

      for (Agent agent : agents) {
        if (PVector.dist(candidate, agent.position) < 48) {
          open = false;
          break;
        }
      }

      if (open) {
        return candidate;
      }
    }

    return new PVector(random(minX, maxX), random(minY, maxY));
  }

  void createConnections() {
    for (Agent follower : agents) {
      int desiredConnections = 2 + int(random(2));

      while (countFollowing(follower) < desiredConnections) {
        Agent followed = agents.get(int(random(agents.size())));

        if (follower != followed && !hasConnection(follower, followed)) {
          connections.add(new Connection(follower, followed));
        }
      }
    }
  }

  int countFollowing(Agent agent) {
    int count = 0;

    for (Connection connection : connections) {
      if (connection.follower == agent) {
        count++;
      }
    }

    return count;
  }

  int countFollowers(Agent agent) {
    int count = 0;

    for (Connection connection : connections) {
      if (connection.followed == agent) {
        count++;
      }
    }

    return count;
  }

  boolean hasConnection(Agent follower, Agent followed) {
    return findConnection(follower, followed) != null;
  }

  Connection findConnection(Agent follower, Agent followed) {
    for (Connection connection : connections) {
      if (connection.follower == follower && connection.followed == followed) {
        return connection;
      }
    }

    return null;
  }

  void refreshAllFollowerCounts(boolean animate) {
    for (Agent agent : agents) {
      agent.setFollowerCount(countFollowers(agent), animate);
    }
  }

  void refreshFollowerCount(Agent agent, boolean animate) {
    agent.setFollowerCount(countFollowers(agent), animate);
  }

  boolean addConnection(Agent follower, Agent followed, boolean animate) {
    if (follower == followed || hasConnection(follower, followed)) {
      return false;
    }

    connections.add(new Connection(follower, followed));
    refreshFollowerCount(followed, animate);
    return true;
  }

  boolean removeConnection(Agent follower, Agent followed, boolean animate) {
    Connection connection = findConnection(follower, followed);

    if (connection == null) {
      return false;
    }

    connections.remove(connection);
    refreshFollowerCount(followed, animate);
    return true;
  }

  void evaluateRelationship(Agent viewer, Agent author) {
    float opinionDistance = abs(viewer.opinion - author.opinion);
    boolean currentlyFollowing = hasConnection(viewer, author);

    if (!currentlyFollowing &&
      opinionDistance < FOLLOW_DISTANCE &&
      random(1) < FOLLOW_PROBABILITY) {
      addConnection(viewer, author, true);
    } else if (currentlyFollowing &&
      opinionDistance > UNFOLLOW_DISTANCE &&
      random(1) < UNFOLLOW_PROBABILITY) {
      removeConnection(viewer, author, true);
    }
  }

  boolean isAlreadyReceiving(Agent candidate) {
    for (Message message : messages) {
      if (message.receiver == candidate) {
        return true;
      }
    }

    return false;
  }

  void update() {
    int now = millis();
    float deltaSeconds = min((now - previousMillis) / 1000.0, 0.05);
    previousMillis = now;

    if (paused) {
      return;
    }

    float scaledDelta = deltaSeconds * speedMultiplier;

    for (Agent agent : agents) {
      agent.update(scaledDelta);
    }

    for (int index = messages.size() - 1; index >= 0; index--) {
      Message message = messages.get(index);
      message.update(scaledDelta);

      if (message.readyToDeliver()) {
        message.receiver.receive(message.stance);
        evaluateRelationship(message.receiver, message.author);
        message.markDelivered();
      }

      if (message.finished()) {
        messages.remove(index);
      }
    }

    if (currentSpeaker != null && messages.isEmpty()) {
      if (cycleSettleTime <= 0) {
        cycleSettleTime = 0.55;
      }

      cycleSettleTime -= scaledDelta;

      if (cycleSettleTime > 0) {
        return;
      }

      currentSpeaker.speaking = false;
      currentSpeaker = null;
      cycleSettleTime = 0;

      if (pauseAfterCurrentCycle) {
        pauseAfterCurrentCycle = false;
        paused = true;
        return;
      }
    }

    if (currentSpeaker == null) {
      timeUntilNextPost -= scaledDelta;

      if (timeUntilNextPost <= 0) {
        beginNextPost();
      }
    }
  }

  void beginNextPost() {
    if (agents.isEmpty() || currentSpeaker != null) {
      return;
    }

    currentSpeaker = chooseSpeaker();
    currentSpeaker.beginSpeaking();
    cycleSettleTime = 0;
    cycleCount++;

    ArrayList<Connection> available = new ArrayList<Connection>();

    for (Connection connection : connections) {
      if (connection.followed == currentSpeaker) {
        available.add(connection);
      }
    }

    int audienceLimit = currentSpeaker.leader ? 5 : 2;
    int audienceSize = min(audienceLimit, available.size());

    for (int index = 0; index < audienceSize; index++) {
      int connectionIndex = int(random(available.size()));
      Connection connection = available.remove(connectionIndex);

      messages.add(
        new Message(
          currentSpeaker,
          connection.follower,
          currentSpeaker.opinion
        )
      );
    }

    addDiscoveryMessages();

    timeUntilNextPost = 0.75;
  }

  void addDiscoveryMessages() {
    int discoverySlots = currentSpeaker.leader ? 2 : 1;

    for (int slot = 0; slot < discoverySlots; slot++) {
      float chance = currentSpeaker.leader ? min(1, DISCOVERY_PROBABILITY + 0.2) : DISCOVERY_PROBABILITY;

      if (random(1) >= chance && !messages.isEmpty()) {
        continue;
      }

      ArrayList<Agent> candidates = new ArrayList<Agent>();

      for (Agent candidate : agents) {
        if (candidate != currentSpeaker &&
          !hasConnection(candidate, currentSpeaker) &&
          !isAlreadyReceiving(candidate)) {
          candidates.add(candidate);
        }
      }

      if (candidates.isEmpty()) {
        return;
      }

      Agent receiver = candidates.get(int(random(candidates.size())));
      messages.add(new Message(currentSpeaker, receiver, currentSpeaker.opinion));
    }
  }

  Agent chooseSpeaker() {
    float totalWeight = 0;

    for (Agent agent : agents) {
      totalWeight += agent.speakingWeight();
    }

    float choice = random(totalWeight);

    for (Agent agent : agents) {
      choice -= agent.speakingWeight();

      if (choice <= 0) {
        return agent;
      }
    }

    return agents.get(agents.size() - 1);
  }

  void display() {
    for (Connection connection : connections) {
      connection.display(showFullNetwork, selectedAgent);
    }

    for (Message message : messages) {
      message.display();
    }

    for (Agent agent : agents) {
      agent.display();
    }

    displayInspector();
  }

  void displayInspector() {
    float panelX = width - PANEL_WIDTH;

    noStroke();
    fill(25, 28, 37, 245);
    rect(panelX, 66, PANEL_WIDTH, height - 66);

    fill(234);
    textAlign(LEFT, TOP);
    textSize(14);
    text("AGENT INSPECTOR", panelX + 24, 96);

    if (selectedAgent == null) {
      fill(137, 143, 157);
      textSize(13);
      textLeading(20);
      text("Click an agent to inspect\nits current state.", panelX + 24, 132);
      displayLegend(panelX + 24, height - 154);
      return;
    }

    fill(245);
    textSize(22);
    text("Agent " + selectedAgent.id, panelX + 24, 134);

    fill(158, 165, 180);
    textSize(13);
    text("Opinion", panelX + 24, 184);
    text("Activity", panelX + 24, 222);
    text("Leader", panelX + 24, 260);
    text("Followers", panelX + 24, 298);
    text("Following", panelX + 24, 336);

    fill(239);
    textAlign(RIGHT, TOP);
    text(nf(selectedAgent.opinion, 1, 2), width - 24, 184);
    text(nf(selectedAgent.activity, 1, 2), width - 24, 222);
    text(selectedAgent.leader ? "Yes" : "No", width - 24, 260);
    text(countFollowers(selectedAgent), width - 24, 298);
    text(countFollowing(selectedAgent), width - 24, 336);

    textAlign(LEFT, TOP);
    fill(selectedAgent.opinionColor());
    rect(panelX + 24, 378, PANEL_WIDTH - 48, 8, 4);

    displayLegend(panelX + 24, height - 154);
  }

  void displayLegend(float x, float y) {
    fill(158, 165, 180);
    textAlign(LEFT, TOP);
    textSize(12);
    text("OPINION", x, y);

    for (int index = 0; index < 120; index++) {
      float opinion = map(index, 0, 119, -1, 1);
      stroke(opinionToColor(opinion));
      line(x + index, y + 27, x + index, y + 37);
    }

    noStroke();
    fill(130, 136, 150);
    text("-1", x, y + 44);
    textAlign(RIGHT, TOP);
    text("+1", x + 120, y + 44);

    textAlign(LEFT, TOP);
    fill(130, 136, 150);
    text("Size = followers", x, y + 78);
    text("Double ring = opinion leader", x, y + 98);
    text("E reveals hidden relationships", x, y + 118);
  }

  void selectAgentAt(float x, float y) {
    selectedAgent = null;

    for (int index = agents.size() - 1; index >= 0; index--) {
      Agent agent = agents.get(index);

      if (agent.containsPoint(x, y)) {
        selectedAgent = agent;
        break;
      }
    }

    for (Agent agent : agents) {
      agent.selected = agent == selectedAgent;
    }
  }

  void togglePaused() {
    paused = !paused;
    pauseAfterCurrentCycle = false;
    previousMillis = millis();
  }

  void stepOnce() {
    pauseAfterCurrentCycle = true;
    paused = false;
    previousMillis = millis();

    if (currentSpeaker == null && messages.isEmpty()) {
      beginNextPost();
    }
  }

  void changeSpeed(float amount) {
    speedMultiplier = constrain(speedMultiplier + amount, 0.25, 4.0);
  }

  void toggleNetwork() {
    showFullNetwork = !showFullNetwork;
  }
}

color opinionToColor(float opinion) {
  color negative = color(217, 92, 137);
  color neutral = color(231, 225, 214);
  color positive = color(77, 180, 191);
  float value = constrain(opinion, -1, 1);

  if (value < 0) {
    return lerpColor(neutral, negative, -value);
  }

  return lerpColor(neutral, positive, value);
}
