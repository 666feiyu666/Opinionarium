class World {
  ArrayList<Agent> agents = new ArrayList<Agent>();
  ArrayList<Connection> connections = new ArrayList<Connection>();
  ArrayList<Message> messages = new ArrayList<Message>();

  Agent selectedAgent;
  Agent currentSpeaker;

  boolean paused = false;
  boolean pauseAfterCurrentCycle = false;

  float speedMultiplier = 1.0;
  float timeUntilNextPost = 0.7;
  int cycleCount = 0;
  int resetCount = 0;
  int previousMillis;

  final int AGENT_COUNT = 30;
  final float PANEL_WIDTH = 260;

  void reset() {
    agents.clear();
    connections.clear();
    messages.clear();

    selectedAgent = null;
    currentSpeaker = null;
    paused = false;
    pauseAfterCurrentCycle = false;
    speedMultiplier = 1.0;
    timeUntilNextPost = 0.7;
    cycleCount = 0;

    randomSeed(4700 + resetCount);
    resetCount++;

    createAgents();
    createConnections();
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
    for (Agent source : agents) {
      int desiredConnections = 2 + int(random(2));

      while (countOutgoingConnections(source) < desiredConnections) {
        Agent target = agents.get(int(random(agents.size())));

        if (source != target && !hasConnection(source, target)) {
          connections.add(new Connection(source, target));
        }
      }
    }
  }

  int countOutgoingConnections(Agent source) {
    int count = 0;

    for (Connection connection : connections) {
      if (connection.source == source) {
        count++;
      }
    }

    return count;
  }

  boolean hasConnection(Agent source, Agent target) {
    for (Connection connection : connections) {
      if (connection.source == source && connection.target == target) {
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

      if (message.finished()) {
        messages.remove(index);
      }
    }

    if (currentSpeaker != null && messages.isEmpty()) {
      currentSpeaker.speaking = false;
      currentSpeaker = null;

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
    currentSpeaker.speaking = true;
    cycleCount++;

    ArrayList<Connection> available = new ArrayList<Connection>();

    for (Connection connection : connections) {
      if (connection.source == currentSpeaker) {
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
          connection.source,
          connection.target,
          currentSpeaker.opinion
        )
      );
    }

    timeUntilNextPost = 0.75;
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
      connection.display();
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
    text("Following", panelX + 24, 298);

    fill(239);
    textAlign(RIGHT, TOP);
    text(nf(selectedAgent.opinion, 1, 2), width - 24, 184);
    text(nf(selectedAgent.activity, 1, 2), width - 24, 222);
    text(selectedAgent.leader ? "Yes" : "No", width - 24, 260);
    text(countOutgoingConnections(selectedAgent), width - 24, 298);

    textAlign(LEFT, TOP);
    fill(selectedAgent.opinionColor());
    rect(panelX + 24, 338, PANEL_WIDTH - 48, 8, 4);

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
    text("Gold ring = opinion leader", x, y + 78);
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
}

color opinionToColor(float opinion) {
  color negative = color(228, 83, 81);
  color neutral = color(224, 226, 231);
  color positive = color(78, 137, 230);
  float value = constrain(opinion, -1, 1);

  if (value < 0) {
    return lerpColor(neutral, negative, -value);
  }

  return lerpColor(neutral, positive, value);
}
