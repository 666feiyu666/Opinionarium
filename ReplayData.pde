class Belief {
  final double a, b;
  Belief(double a, double b) { this.a = a; this.b = b; }
  float opinion() { return (float)(2 * a / (a + b) - 1); }
}

class RecordedMessage {
  final String id;
  final int producer, stance;
  RecordedMessage(String id, int producer, int stance) {
    this.id = id; this.producer = producer; this.stance = stance;
  }
}

class RecordedExposure {
  final RecordedMessage message;
  final int consumer;
  RecordedExposure(RecordedMessage message, int consumer) {
    this.message = message; this.consumer = consumer;
  }
}

class RecordedOrigin {
  final boolean posted;
  final double probability;
  final String messageId;
  RecordedOrigin(boolean posted, double probability, String messageId) {
    this.posted = posted; this.probability = probability; this.messageId = messageId;
  }
}

class RecordedEvidence {
  final int support, oppose;
  final double weightedSupport, weightedOppose;
  RecordedEvidence(int support, int oppose, double ws, double wo) {
    this.support = support; this.oppose = oppose;
    weightedSupport = ws; weightedOppose = wo;
  }
}

class ReplayRound {
  Belief[] states;
  RecordedOrigin[] origins;
  RecordedEvidence[] evidence;
  ArrayList<int[]> edges = new ArrayList<int[]>();
  HashMap<String, RecordedMessage> messages = new HashMap<String, RecordedMessage>();
  ArrayList<RecordedExposure> exposures = new ArrayList<RecordedExposure>();
  ReplayRound(int n) {
    states = new Belief[n];
    origins = new RecordedOrigin[n];
    evidence = new RecordedEvidence[n];
  }
}

class ReplayData {
  int[] ids;
  HashMap<Integer, Integer> index = new HashMap<Integer, Integer>();
  HashSet<Integer> leaders = new HashSet<Integer>();
  ReplayRound[] rounds;
  String scenario, orientation, directory, revision;
  int seed;
  int totalExposures;
  int size() { return ids.length; }
  int lastRound() { return rounds.length - 1; }
}
