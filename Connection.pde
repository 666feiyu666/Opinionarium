class Connection {
  Agent source;
  Agent target;

  Connection(Agent source, Agent target) {
    this.source = source;
    this.target = target;
  }

  void display() {
    stroke(150, 158, 176, 42);
    strokeWeight(1);
    line(
      source.position.x,
      source.position.y,
      target.position.x,
      target.position.y
    );
  }
}
