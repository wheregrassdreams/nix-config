{ lib }:
schedule:
let
  timeParts = lib.splitString ":" schedule.time;
  hour = lib.toInt (builtins.elemAt timeParts 0);
  minute = lib.toInt (builtins.elemAt timeParts 1);
  weekdays = {
    sunday = {
      launchd = 0;
      systemd = "Sun";
    };
    monday = {
      launchd = 1;
      systemd = "Mon";
    };
    tuesday = {
      launchd = 2;
      systemd = "Tue";
    };
    wednesday = {
      launchd = 3;
      systemd = "Wed";
    };
    thursday = {
      launchd = 4;
      systemd = "Thu";
    };
    friday = {
      launchd = 5;
      systemd = "Fri";
    };
    saturday = {
      launchd = 6;
      systemd = "Sat";
    };
  };
  weekday = weekdays.${schedule.weekday};
in
{
  launchd = {
    inherit hour minute;
    weekday = weekday.launchd;
  };
  systemd =
    if schedule.kind == "daily" then
      "*-*-* ${schedule.time}:00"
    else
      "${weekday.systemd} *-*-* ${schedule.time}:00";
}
