class Agent {
  int id;
  PVector position;

  float opinion;
  float activity;
  float arrivalFlash = 0;

  boolean leader;
  boolean selected = false;
  boolean speaking = false;

  Agent(int id, PVector position, float opinion, float activity, boolean leader) {
    this.id = id;
    this.position = position;
    this.opinion = opinion;
    this.activity = activity;
    this.leader = leader;
  }

  void update(float deltaSeconds) {
    arrivalFlash = max(0, arrivalFlash - deltaSeconds * 1.8);
  }

  void display() {
    float diameter = leader ? 23 : 18;

    if (arrivalFlash > 0) {
      noFill();
      stroke(opinionColor(), 180 * arrivalFlash);
      strokeWeight(2);
      circle(position.x, position.y, diameter + 18 * arrivalFlash);
    }

    if (leader) {
      noFill();
      stroke(238, 184, 76, 230);
      strokeWeight(2.5);
      circle(position.x, position.y, diameter + 11);
    }

    if (selected) {
      noFill();
      stroke(255, 245);
      strokeWeight(2);
      circle(position.x, position.y, diameter + 19);
    }

    if (speaking) {
      noFill();
      stroke(255, 210);
      strokeWeight(2);
      float pulse = 10 + 5 * sin(millis() * 0.012);
      circle(position.x, position.y, diameter + pulse);
    }

    noStroke();
    fill(opinionColor());
    circle(position.x, position.y, diameter);
  }

  boolean containsPoint(float x, float y) {
    float hitRadius = leader ? 18 : 14;
    return dist(x, y, position.x, position.y) <= hitRadius;
  }

  float speakingWeight() {
    return activity * (leader ? 2.4 : 1.0);
  }

  void receive(float messageStance) {
    float influenceRate = leader ? 0.08 : 0.16;
    opinion += influenceRate * (messageStance - opinion);
    opinion = constrain(opinion, -1, 1);
    arrivalFlash = 1;
  }

  color opinionColor() {
    return opinionToColor(opinion);
  }
}
