class Agent {
  int id;
  PVector position;

  float opinion;
  float displayedOpinion;
  float activity;
  float arrivalFlash = 0;
  float degreePulse = 0;
  float degreePulseDirection = 0;
  float emissionPulse = 0;
  float targetRadius;
  float displayRadius;
  float breathPhase;

  int followerCount = 0;

  boolean leader;
  boolean selected = false;
  boolean speaking = false;

  final float MIN_RADIUS = 9;
  final float MAX_RADIUS = 38;
  final float AREA_PER_FOLLOWER = 90;

  Agent(int id, PVector position, float opinion, float activity, boolean leader) {
    this.id = id;
    this.position = position;
    this.opinion = opinion;
    this.displayedOpinion = opinion;
    this.activity = activity;
    this.leader = leader;
    this.breathPhase = random(TWO_PI);
    this.targetRadius = radiusForFollowerCount(0);
    this.displayRadius = targetRadius;
  }

  void update(float deltaSeconds) {
    arrivalFlash = max(0, arrivalFlash - deltaSeconds * 1.8);
    degreePulse = max(0, degreePulse - deltaSeconds * 1.25);
    emissionPulse = max(0, emissionPulse - deltaSeconds * 1.7);

    float opinionBlend = min(1, deltaSeconds * 5.5);
    float radiusBlend = min(1, deltaSeconds * 5.0);
    displayedOpinion = lerp(displayedOpinion, opinion, opinionBlend);
    displayRadius = lerp(displayRadius, targetRadius, radiusBlend);
  }

  void display() {
    float diameter = displayRadius * 2;
    float breath = 0.5 + 0.5 * sin(millis() * (0.0012 + activity * 0.0012) + breathPhase);
    float auraDiameter = diameter + 7 + breath * 4;

    noStroke();
    fill(opinionColor(), 18 + 18 * breath);
    circle(position.x, position.y, auraDiameter);

    if (degreePulse > 0) {
      float pulseProgress = 1 - degreePulse;
      float pulseOffset;

      if (degreePulseDirection > 0) {
        pulseOffset = 4 + pulseProgress * 18;
      } else {
        pulseOffset = 5 + degreePulse * 18;
      }

      noFill();
      stroke(239, 242, 247, 150 * degreePulse);
      strokeWeight(1.4);
      circle(position.x, position.y, diameter + pulseOffset);
    }

    if (arrivalFlash > 0) {
      noFill();
      stroke(opinionColor(), 185 * arrivalFlash);
      strokeWeight(1.8);
      float rippleProgress = 1 - arrivalFlash;
      circle(position.x, position.y, diameter + 7 + rippleProgress * 24);
    }

    if (leader) {
      noFill();
      stroke(224, 229, 239, 150);
      strokeWeight(1.2);
      circle(position.x, position.y, diameter + 9);
      stroke(224, 229, 239, 70);
      circle(position.x, position.y, diameter + 15 + breath * 2);
    }

    if (selected) {
      noFill();
      stroke(255, 245);
      strokeWeight(2);
      circle(position.x, position.y, diameter + (leader ? 23 : 14));
    }

    if (speaking) {
      noFill();
      stroke(255, 55 + 155 * emissionPulse);
      strokeWeight(1.8);
      float pulse = 11 + (1 - emissionPulse) * 17;
      circle(position.x, position.y, diameter + pulse);
    }

    noStroke();
    fill(0, 30);
    circle(position.x + 2, position.y + 3, diameter + 2);

    fill(opinionColor());
    circle(position.x, position.y, diameter);

    fill(255, 28);
    circle(
      position.x - displayRadius * 0.28,
      position.y - displayRadius * 0.30,
      max(3, displayRadius * 0.58)
    );
  }

  boolean containsPoint(float x, float y) {
    float hitRadius = displayRadius + (leader ? 10 : 6);
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

  void beginSpeaking() {
    speaking = true;
    emissionPulse = 1;
  }

  void setFollowerCount(int newFollowerCount, boolean animate) {
    int difference = newFollowerCount - followerCount;
    followerCount = newFollowerCount;
    targetRadius = radiusForFollowerCount(followerCount);

    if (!animate) {
      displayRadius = targetRadius;
    } else if (difference != 0) {
      degreePulseDirection = difference > 0 ? 1 : -1;
      degreePulse = 1;
    }
  }

  float radiusForFollowerCount(int count) {
    return min(MAX_RADIUS, sqrt(MIN_RADIUS * MIN_RADIUS + count * AREA_PER_FOLLOWER));
  }

  color opinionColor() {
    return opinionToColor(displayedOpinion);
  }
}
