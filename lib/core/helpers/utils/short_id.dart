/// Returns the first [length] characters of [value], uppercased.
///
/// Safe for values shorter than [length] (including empty strings).
/// The previous inline implementation (`value.substring(0, 8)`) threw
/// `RangeError` while building the reservations list and the order success
/// sheet whenever an id was shorter than 8 characters.
String shortId(String value, {int length = 8}) {
  if (value.length <= length) return value.toUpperCase();
  return value.substring(0, length).toUpperCase();
}
