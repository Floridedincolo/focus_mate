class CalendarIconData {
  static List<String> months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];
  static List<String> weekdays = [
    "Monday", "Tuesday", "Wednesday", "Thursday",
    "Friday", "Saturday", "Sunday",
  ];

  late DateTime dateTime;
  late String month;
  late String weekday;
  late int day;
  late int year;

  CalendarIconData(this.dateTime) {
    month = months[dateTime.month - 1];
    weekday = weekdays[dateTime.weekday - 1];
    day = dateTime.day;
    year = dateTime.year;
  }
}

