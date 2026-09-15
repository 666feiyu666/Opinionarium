// Reads the model's existing tables; no model rules are evaluated here.
class ReplayLoader {
  String context = "";
  void require(boolean valid, String reason) {
    if (!valid) throw new IllegalArgumentException(context + ": " + reason);
  }
  int integer(TableRow row, String field) {
    return Integer.parseInt(row.getString(field));
  }
  double number(TableRow row, String field) {
    double value = Double.parseDouble(row.getString(field));
    require(Double.isFinite(value), field + " must be finite");
    return value;
  }
  boolean bool(TableRow row, String field) {
    String value = row.getString(field);
    require(value.equalsIgnoreCase("true") || value.equalsIgnoreCase("false"), "invalid " + field);
    return Boolean.parseBoolean(value);
  }
  Table table(File folder, String name, String... fields) {
    context = name;
    File file = new File(folder, name + ".csv");
    require(file.isFile(), "missing file");
    Table table = loadTable(file.getAbsolutePath(), "header,csv");
    require(table != null, "could not read CSV");
    HashSet<String> columns = new HashSet<String>(Arrays.asList(table.getColumnTitles()));
    for (String field : fields) require(columns.contains(field), "missing column " + field);
    return table;
  }
  int node(ReplayData data, TableRow row, String field) {
    int id = integer(row, field);
    require(data.index.containsKey(id), "unknown " + field + " " + id);
    return data.index.get(id);
  }
  int round(ReplayData data, TableRow row, boolean allowZero) {
    int r = integer(row, "round");
    context += " round " + r;
    require(r >= (allowZero ? 0 : 1) && r <= data.lastRound(), "invalid round");
    return r;
  }
  void same(double value, double expected, String field) {
    require(Math.abs(value - expected) <= 1e-10 * Math.max(1, Math.abs(expected)), field + " disagrees with state");
  }
  ReplayData load(File folder) {
    long started = System.nanoTime();
    try {
      context = "manifest.json";
      require(new File(folder, "manifest.json").isFile(), "missing file");
      JSONObject manifest = loadJSONObject(new File(folder, "manifest.json").getAbsolutePath());
      require(manifest != null, "could not read metadata");
      ReplayData data = new ReplayData();
      data.directory = folder.getAbsolutePath();
      data.scenario = manifest.getString("scenario");
      data.orientation = manifest.getString("orientation");
      data.seed = manifest.getInt("seed");
      data.revision = manifest.getString("model_revision");
      int n = manifest.getInt("agent_count");
      int count = manifest.getInt("rounds");
      require(n > 0 && count >= 0, "invalid size or round count");
      // Saved hashes also detect truncated tables, including missing network rows.
      if (manifest.hasKey("files")) {
        JSONObject hashes = manifest.getJSONObject("files");
        for (String name : new String[]{"states", "origination", "messages", "exposures", "aggregates", "network"}) {
          context = name + ".csv";
          byte[] bytes = java.nio.file.Files.readAllBytes(new File(folder, name + ".csv").toPath());
          byte[] digest = java.security.MessageDigest.getInstance("SHA-256").digest(bytes);
          StringBuilder hex = new StringBuilder();
          for (byte b : digest) hex.append(String.format("%02x", b & 255));
          require(hex.toString().equals(hashes.getString(name + ".csv")), "checksum mismatch");
        }
      }
      Table states = table(folder, "states", "round", "agent_id", "a", "b", "signed_mean");
      TreeSet<Integer> ids = new TreeSet<Integer>();
      for (TableRow row : states.rows()) if (integer(row, "round") == 0) ids.add(integer(row, "agent_id"));
      require(ids.size() == n, "initial node count disagrees with manifest");
      data.ids = new int[n];
      int i = 0;
      for (int id : ids) { require(id >= 0, "negative ID"); data.ids[i] = id; data.index.put(id, i++); }
      data.rounds = new ReplayRound[count + 1];
      for (int r = 0; r <= count; r++) data.rounds[r] = new ReplayRound(n);
      int line = 1;
      for (TableRow row : states.rows()) {
        context = "states.csv row " + (++line);
        int r = round(data, row, true), a = node(data, row, "agent_id");
        require(data.rounds[r].states[a] == null, "duplicate node state");
        double aa = number(row, "a"), bb = number(row, "b");
        require(aa > 0 && bb > 0 && Double.isFinite(aa + bb), "invalid Beta parameters");
        same(number(row, "signed_mean"), 2 * aa / (aa + bb) - 1, "signed_mean");
        data.rounds[r].states[a] = new Belief(aa, bb);
      }
      for (int r = 0; r <= count; r++) for (i = 0; i < n; i++) {
        context = "states.csv round " + r;
        require(data.rounds[r].states[i] != null, "missing node " + data.ids[i]);
      }
      context = "manifest.json leader_ids";
      JSONArray leaders = manifest.getJSONArray("leader_ids");
      for (i = 0; i < leaders.size(); i++) {
        int id = leaders.getInt(i);
        require(data.index.containsKey(id) && data.leaders.add(id), "invalid or duplicate leader ID");
      }
      Table messages = table(folder, "messages", "round", "message_id", "producer_id", "stance");
      line = 1;
      for (TableRow row : messages.rows()) {
        context = "messages.csv row " + (++line);
        int r = round(data, row, false), a = node(data, row, "producer_id"), stance = integer(row, "stance");
        String id = row.getString("message_id");
        require(id != null && !id.isEmpty() && (stance == -1 || stance == 1), "invalid message");
        require(data.rounds[r].messages.put(id, new RecordedMessage(id, a, stance)) == null, "duplicate message ID");
      }
      Table origins = table(folder, "origination", "round", "agent_id", "did_originate", "origination_probability", "message_id");
      line = 1;
      for (TableRow row : origins.rows()) {
        context = "origination.csv row " + (++line);
        int r = round(data, row, false), a = node(data, row, "agent_id");
        boolean posted = bool(row, "did_originate");
        double probability = number(row, "origination_probability");
        String id = row.getString("message_id");
        if (id == null) id = "";
        RecordedMessage m = data.rounds[r].messages.get(id);
        require(probability >= 0 && probability <= 1, "invalid probability");
        require(posted ? m != null && m.producer == a : id.isEmpty(), "message and origination disagree");
        require(data.rounds[r].origins[a] == null, "duplicate origin");
        data.rounds[r].origins[a] = new RecordedOrigin(posted, probability, id);
      }
      Table exposures = table(folder, "exposures", "round", "consumer_id", "message_id", "producer_id", "stance");
      HashSet<String> seen = new HashSet<String>();
      int[][] support = new int[count + 1][n], oppose = new int[count + 1][n];
      line = 1;
      for (TableRow row : exposures.rows()) {
        context = "exposures.csv row " + (++line);
        int r = round(data, row, false), c = node(data, row, "consumer_id"), p = node(data, row, "producer_id");
        RecordedMessage m = data.rounds[r].messages.get(row.getString("message_id"));
        require(m != null && m.producer == p && m.stance == integer(row, "stance") && p != c, "invalid exposure reference");
        require(seen.add(r + ":" + c + ":" + m.id), "duplicate exposure");
        data.rounds[r].exposures.add(new RecordedExposure(m, c));
        if (m.stance == 1) support[r][c]++; else oppose[r][c]++;
        data.totalExposures++;
      }
      Table network = table(folder, "network", "round", "consumer_id", "producer_id");
      seen.clear(); line = 1;
      for (TableRow row : network.rows()) {
        context = "network.csv row " + (++line);
        int r = round(data, row, true), c = node(data, row, "consumer_id"), p = node(data, row, "producer_id");
        require(c != p && seen.add(r + ":" + c + ":" + p), "self-link or duplicate edge");
        data.rounds[r].edges.add(new int[]{c, p});
      }
      Table aggregates = table(folder, "aggregates", "round", "consumer_id", "n_support", "n_oppose", "weighted_support", "weighted_oppose", "a_before", "b_before", "a_after", "b_after");
      line = 1;
      for (TableRow row : aggregates.rows()) {
        context = "aggregates.csv row " + (++line);
        int r = round(data, row, false), c = node(data, row, "consumer_id");
        int s = integer(row, "n_support"), o = integer(row, "n_oppose");
        double ws = number(row, "weighted_support"), wo = number(row, "weighted_oppose");
        require(s == support[r][c] && o == oppose[r][c] && ws >= 0 && wo >= 0, "evidence disagrees with exposures");
        same(number(row, "a_before"), data.rounds[r-1].states[c].a, "a_before");
        same(number(row, "b_before"), data.rounds[r-1].states[c].b, "b_before");
        same(number(row, "a_after"), data.rounds[r].states[c].a, "a_after");
        same(number(row, "b_after"), data.rounds[r].states[c].b, "b_after");
        require(data.rounds[r].evidence[c] == null, "duplicate evidence");
        data.rounds[r].evidence[c] = new RecordedEvidence(s, o, ws, wo);
      }
      for (int r = 1; r <= count; r++) {
        context = "round " + r;
        int posted = 0;
        for (i = 0; i < n; i++) {
          require(data.rounds[r].origins[i] != null && data.rounds[r].evidence[i] != null, "missing origin or evidence for " + data.ids[i]);
          if (data.rounds[r].origins[i].posted) posted++;
        }
        require(posted == data.rounds[r].messages.size(), "orphan message");
      }
      println("Loaded " + n + " nodes, " + count + " rounds, " + data.totalExposures + " exposures in " + ((System.nanoTime()-started)/1e9) + " s");
      return data;
    } catch (Exception e) {
      throw new IllegalArgumentException(context + ": " + e.getMessage(), e);
    }
  }
}
