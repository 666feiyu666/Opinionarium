World world;

void setup() {
  size(1200, 800, P2D);
  smooth(4);
  surface.setTitle("Opinionarium");

  world = new World();
  world.reset();
}

void draw() {
  background(18, 20, 27);

  world.update();
  world.display();
  displayHeader();
}

void mousePressed() {
  world.selectAgentAt(mouseX, mouseY);
}

void keyPressed() {
  if (key == ' ') {
    world.togglePaused();
  } else if (key == 'r' || key == 'R') {
    world.reset();
  } else if (key == '+' || key == '=') {
    world.changeSpeed(0.25);
  } else if (key == '-' || key == '_') {
    world.changeSpeed(-0.25);
  } else if (key == 'e' || key == 'E') {
    world.toggleNetwork();
  } else if (keyCode == RIGHT) {
    world.stepOnce();
  }
}

void displayHeader() {
  noStroke();
  fill(18, 20, 27, 230);
  rect(0, 0, width, 66);

  fill(244);
  textAlign(LEFT, CENTER);
  textSize(24);
  text("OPINIONARIUM", 28, 29);

  fill(160, 166, 180);
  textSize(12);
  text("SPACE  play / pause     RIGHT  step     R  reset     +/-  speed     E  network", 29, 51);

  textAlign(RIGHT, CENTER);
  fill(world.paused ? color(238, 173, 74) : color(104, 211, 151));
  textSize(13);
  text(world.paused ? "PAUSED" : "PLAYING", width - 172, 29);

  fill(205);
  text(nf(world.speedMultiplier, 0, 2) + "x", width - 112, 29);
  text("Cycle " + world.cycleCount, width - 28, 29);
}
