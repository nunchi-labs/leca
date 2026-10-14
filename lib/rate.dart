/// Reply speed is measured only while the business is open.
const fastReplySeconds = 300;
const defaultOpenHour = 8;
const defaultCloseHour = 21;

bool isWorkingHour(
  DateTime at, {
  int openHour = defaultOpenHour,
  int closeHour = defaultCloseHour,
}) {
  return at.hour >= openHour && at.hour < closeHour;
}

int? averageSeconds(List<int> samples) {
  if (samples.isEmpty) return null;
  var sum = 0;
  for (final sample in samples) {
    sum += sample;
  }
  return sum ~/ samples.length;
}

bool repliesFast(int seconds) => seconds <= fastReplySeconds;

/// Null when the customer wrote outside working hours, or the reply is earlier.
int? inHoursDelay({
  required DateTime asked,
  required DateTime replied,
  int openHour = defaultOpenHour,
  int closeHour = defaultCloseHour,
}) {
  if (!isWorkingHour(asked, openHour: openHour, closeHour: closeHour)) {
    return null;
  }
  final seconds = replied.difference(asked).inSeconds;
  if (seconds < 0) return null;
  return seconds;
}
