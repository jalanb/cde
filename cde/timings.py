"""Methods to handle times"""

import time


def now():
    """Current time

    This method exists only to save other modules an extra import
    """
    return time.time()


def time_since(number_of_seconds):
    """Convert number of seconds to English

    Retain only the two most significant numbers

    >>> assert time_since(time.time() - (13*60*60 + 2*60 + 5)) == '13 hours, 2 minutes'
    """
    interval = int(abs(float(number_of_seconds)) - time.time())
    interval = int(time.time() - float(number_of_seconds))
    minutes, seconds = divmod(interval, 60)
    if not minutes:
        return "%s seconds" % seconds
    hours, minutes = divmod(minutes, 60)
    if not hours:
        return "%s minutes, %s seconds" % (minutes, seconds)
    days, hours = divmod(hours, 24)
    if not days:
        return "%s hours, %s minutes" % (hours, minutes)
    years, days = divmod(days, 365)
    if not years:
        return "%s days, %s hours" % (days, hours)
    return "%s years, %s days" % (years, days)
