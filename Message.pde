class Message {
  Agent author;
  Agent receiver;

  float stance;
  float progress = 0;
  float travelSpeed;
  boolean delivered = false;
  PVector controlPoint;

  Message(Agent author, Agent receiver, float stance) {
    this.author = author;
    this.receiver = receiver;
    this.stance = stance;
    this.travelSpeed = random(0.62, 0.86);
    this.controlPoint = createControlPoint();
  }

  void update(float deltaSeconds) {
    progress = min(1, progress + deltaSeconds * travelSpeed);
  }

  void display() {
    float easedProgress = smoothStep(progress);

    noFill();
    stroke(opinionToColor(stance), 58);
    strokeWeight(1.2);
    beginShape();
    int pathSegments = 24;

    for (int index = 0; index <= pathSegments; index++) {
      float pathProgress = easedProgress * index / float(pathSegments);
      PVector point = pointOnCurve(pathProgress);
      vertex(point.x, point.y);
    }

    endShape();

    int trailCount = 7;

    for (int index = trailCount; index >= 1; index--) {
      float trailProgress = max(0, easedProgress - index * 0.032);
      PVector trailPosition = pointOnCurve(trailProgress);
      float trailStrength = 1 - index / float(trailCount + 1);

      noStroke();
      fill(opinionToColor(stance), 80 * trailStrength);
      circle(trailPosition.x, trailPosition.y, 3 + 4 * trailStrength);
    }

    PVector currentPosition = pointOnCurve(easedProgress);

    noStroke();
    fill(opinionToColor(stance), 34);
    circle(currentPosition.x, currentPosition.y, 20);

    fill(opinionToColor(stance), 95);
    circle(currentPosition.x, currentPosition.y, 13);

    fill(opinionToColor(stance));
    circle(currentPosition.x, currentPosition.y, 7);
  }

  boolean finished() {
    return progress >= 1 && delivered;
  }

  boolean readyToDeliver() {
    return progress >= 1 && !delivered;
  }

  void markDelivered() {
    delivered = true;
  }

  float smoothStep(float value) {
    return value * value * (3 - 2 * value);
  }

  PVector createControlPoint() {
    PVector midpoint = PVector.add(author.position, receiver.position).mult(0.5);
    PVector direction = PVector.sub(receiver.position, author.position);
    float distance = max(1, direction.mag());
    PVector normal = new PVector(-direction.y / distance, direction.x / distance);
    float bendDirection = random(1) < 0.5 ? -1 : 1;
    float bendAmount = constrain(distance * 0.18, 18, 64) * bendDirection;

    return midpoint.add(normal.mult(bendAmount));
  }

  PVector pointOnCurve(float value) {
    float t = constrain(value, 0, 1);
    float inverse = 1 - t;
    float x = inverse * inverse * author.position.x +
      2 * inverse * t * controlPoint.x +
      t * t * receiver.position.x;
    float y = inverse * inverse * author.position.y +
      2 * inverse * t * controlPoint.y +
      t * t * receiver.position.y;

    return new PVector(x, y);
  }
}
