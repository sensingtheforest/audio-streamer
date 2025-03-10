from pathlib import Path
import os
from datetime import datetime, timedelta
import time
import zoneinfo
from astral import LocationInfo
from astral.sun import sun



#################################################
# Define the following parameters

# Location for the solar time
location = LocationInfo("Alice Holt Forest", "UK", "Europe/London", 51.1699307, -0.8371404)

# The ratios array that determines the solar times: 0 = sunrise, 1 = solar noon, 2 = sunset. 
# Decimal values are interpolations (e.g., 1.5 is the time between solar noon and sunset, etc.)
solar_ratios = [0.0, 1.0, 1.9, 2.5]  # <---- CHANGE THESE RATIOS TO CHANGE THE SOLAR TIMES

PROJECT_DIR = Path(__file__).resolve().parent  # Absolute path of the folder where this script is
commands = [""] * len(solar_ratios)  # Initialize array with same length as solar_ratios

# Define separate scripts for each solar event. 
commands[0] = os.path.join(PROJECT_DIR, "record.sh") 
commands[1] = os.path.join(PROJECT_DIR, "record.sh")  
commands[2] = os.path.join(PROJECT_DIR, "record.sh") 
commands[3] = os.path.join(PROJECT_DIR, "record.sh")  

#################################################



# The path of the log file. No worries if it's the same for other scripts, this script only appends lines.
log_file = os.path.join(PROJECT_DIR, 'sys.log')

tz = zoneinfo.ZoneInfo(location.timezone)


# Log function
def log_message(message):
    current_time = datetime.now(tz).strftime('%d-%b-%Y %H:%M:%S')
    with open(log_file, 'a') as log:
        log.write(f"{current_time} - solar-crontab.py - {message}\n")


# Execute a bash command
def execute_bash(command):
    if command is None or command.strip() == "":  # Check for None or empty string (even spaces)
        log_message("Warning: Command is empty. Nothing will be executed.")
        return
    os.system(command)


# Get sunrise, solar noon, and sunset times
def get_sun_times(location):
    today = datetime.now(tz).date()
    sun_times = sun(location.observer, date=today, tzinfo=tz)
    return sun_times["sunrise"], sun_times["sunset"], sun_times["noon"]


# Convert datetime to timedelta since midnight
def datetime_to_timedelta(dt):
    return timedelta(hours=dt.hour, minutes=dt.minute, seconds=dt.second)


# Calculate intermediate times based on ratios
def calculate_intermediate_time(start, end, ratio):
    difference = end - start
    scaled_difference = difference * ratio
    return start + scaled_difference


# Convert solar ratios to exact event times
def convert_ratios_to_times(ratios, sunrise, solar_noon, sunset):
    sunrise_td = datetime_to_timedelta(sunrise)
    solar_noon_td = datetime_to_timedelta(solar_noon)
    sunset_td = datetime_to_timedelta(sunset)
    times = []

    for ratio in ratios:
        if ratio <= 1:
            intermediate_td = calculate_intermediate_time(sunrise_td, solar_noon_td, ratio)
        elif ratio <= 2:
            intermediate_td = calculate_intermediate_time(solar_noon_td, sunset_td, ratio - 1)
        else:
            intermediate_td = calculate_intermediate_time(sunset_td, sunrise_td + timedelta(days=1), ratio - 2)
        # Convert timedelta back to datetime
        intermediate_time = datetime.combine(datetime.today(), datetime.min.time(), tz) + intermediate_td
        times.append(intermediate_time)

    return times


# Print and log solar times
def print_solar_times(ratios, times):
    for ratio, time in zip(ratios, times):
        print(f"Ratio: {ratio}, Time: {time.strftime('%H:%M:%S')}")


def log_solar_times(ratios, times):
    for ratio, time in zip(ratios, times):
        log_message(f"Ratio: {ratio}, Time: {time.strftime('%H:%M:%S')}")


# Calculate time delay until the next event
def calculate_delay(target_time):
    now = datetime.now(tz)
    delay = (target_time - now).total_seconds()
    return delay + 86400 if delay < 0 else delay  # Add 24 hours if event is in the past


# Log initial location and sun information
log_message(f"Location: {location.name}, {location.region}")
log_message(f"Latitude: {location.latitude} - Longitude: {location.longitude}")

sunrise, sunset, solar_noon = get_sun_times(location)
solar_times = convert_ratios_to_times(solar_ratios, sunrise, solar_noon, sunset)
log_solar_times(solar_ratios, solar_times)


if __name__ == "__main__":
    while True:
        sunrise, sunset, solar_noon = get_sun_times(location)
        solar_times = convert_ratios_to_times(solar_ratios, sunrise, solar_noon, sunset)

        log_message(f"Sunrise: {sunrise}, Sunset: {sunset}, Solar Noon: {solar_noon}")

        # Compute delays for each event
        delays = [calculate_delay(event_time) for event_time in solar_times]

        next_event_index = delays.index(min(delays))
        next_event_time = solar_times[next_event_index]
        next_event_delay = delays[next_event_index]
        next_ratio = solar_ratios[next_event_index]
        next_command = commands[next_event_index]

        log_message(f"Sleeping until next event in {next_event_delay} seconds")
        time.sleep(next_event_delay)

        execute_bash(next_command)
        log_message(f"Executed command for ratio {next_ratio} at time {next_event_time.strftime('%H:%M:%S')}")

        # Sleep for a minute before recalculating to avoid duplicate runs
        time.sleep(60)
