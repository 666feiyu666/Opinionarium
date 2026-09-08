class Connection {
  Agent follower;
  Agent followed;

  Connection(Agent follower, Agent followed) {
    this.follower = follower;
    this.followed = followed;
  }

  void display(boolean fullNetwork, Agent selectedAgent) {
    boolean localConnection = selectedAgent != null &&
      (follower == selectedAgent || followed == selectedAgent);

    if (!fullNetwork && !localConnection) {
      return;
    }

    float alpha = localConnection ? 105 : 28;
    stroke(161, 170, 190, alpha);
    strokeWeight(1);
    line(
      follower.position.x,
      follower.position.y,
      followed.position.x,
      followed.position.y
    );

    displayArrow(alpha);
  }

  void displayArrow(float alpha) {
    float x = lerp(follower.position.x, followed.position.x, 0.72);
    float y = lerp(follower.position.y, followed.position.y, 0.72);
    float angle = atan2(
      followed.position.y - follower.position.y,
      followed.position.x - follower.position.x
    );

    pushMatrix();
    translate(x, y);
    rotate(angle);
    stroke(184, 191, 207, alpha);
    line(0, 0, -5, -3);
    line(0, 0, -5, 3);
    popMatrix();
  }
}
