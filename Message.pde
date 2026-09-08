class Message {
  Agent author;
  Agent receiver;

  float stance;
  float progress = 0;
  float travelSpeed;
  boolean influenceApplied = false;

  Message(Agent author, Agent receiver, float stance) {
    this.author = author;
    this.receiver = receiver;
    this.stance = stance;
    this.travelSpeed = random(0.65, 0.95);
  }

  void update(float deltaSeconds) {
    progress = min(1, progress + deltaSeconds * travelSpeed);

    if (progress >= 1 && !influenceApplied) {
      receiver.receive(stance);
      influenceApplied = true;
    }
  }

  void display() {
    float easedProgress = smoothStep(progress);
    PVector currentPosition = PVector.lerp(
      author.position,
      receiver.position,
      easedProgress
    );

    noStroke();
    fill(opinionToColor(stance));
    circle(currentPosition.x, currentPosition.y, 8);

    fill(255, 75);
    circle(currentPosition.x, currentPosition.y, 14);
  }

  boolean finished() {
    return progress >= 1 && influenceApplied;
  }

  float smoothStep(float value) {
    return value * value * (3 - 2 * value);
  }
}
