"""
main.py
10. March 2023

measures core voltage and stuff

Author:
Nilusink
"""
import sqlalchemy as db
import typing as tp
import subprocess
import time
import os


INTERVAL: int = 10  # interval in seconds
_T = tp.TypeVar("_T", int, float, str)


META = db.MetaData()
ENGINE: db.Engine = ...

# database configuration
WRITABLE_EMP = db.Table(
    "writable", META,
    db.Column("time", db.INT, primary_key=True),
    db.Column("ram_total", db.INT, nullable=False),
    db.Column("ram_left", db.INT, nullable=False),
    db.Column("disk_read", db.INT, nullable=False),
    db.Column("disk_write", db.INT, nullable=False)
)


CPU_INFO_EMP = db.Table(
    "cpu_info", META,
    db.Column("time", db.INT, primary_key=True),
    db.Column("voltage", db.FLOAT, nullable=False),
    db.Column("clock", db.INT, nullable=False),
    db.Column("temperature", db.FLOAT, nullable=False),
    db.Column("load", db.FLOAT, nullable=False)
)


# create db if it doesn't exist yet
if not os.path.isfile("./main.db"):
    ENGINE = db.create_engine(f'sqlite:///main.db', echo=False)
    META.create_all(ENGINE)


def only_number(inp: str, conv_to: tp.Type[_T] = float) -> _T:
    """
    remove everything except the number

    :param inp: input string
    :param conv_to: type to convert to
    """
    out: str = ""
    for char in str(inp):
        if char.isdigit():
            out += char

        elif char == ".":
            out += char

    return conv_to(out)


def get_memory_info() -> tuple[int, int]:
    """
    get info about physical ram and currently left ram
    :return: physical, left
    :rtype: int, int
    """
    phys = only_number(
        subprocess.check_output(["grep", "MemTotal", "/proc/meminfo"]),
        int
    ) * 1000

    avail = only_number(
        subprocess.check_output(["grep", "MemAvailable", "/proc/meminfo"]),
        int
    ) * 1000

    return phys, avail


def get_usage() -> float:
    """
    get the current cpu usage
    :return: cpu usage in percent
    :rtype: float
    """
    cpu_usage_raw = subprocess.check_output([
        "top", "-bn2",
    ], shell=False).decode()
    loc = cpu_usage_raw.index("id,")

    cpu_usage = loc
    if loc != -1:
        cpu_usage = 100 - float(
            cpu_usage_raw[loc-5:loc-1].replace(",", ".")
        )

    print(cpu_usage)
    return cpu_usage


def read(c: db.Connection):
    core_voltage = only_number(subprocess.check_output(
        ["vcgencmd", "measure_volts"]
    ).decode())
    core_temp = only_number(subprocess.check_output(
        ["vcgencmd", "measure_temp"]
    ).decode())
    core_clock = only_number(subprocess.check_output(
        ["vcgencmd", "measure_clock", "core"]
    ).decode())
    cpu_usage = get_usage()
    mem_phys, mem_avail = get_memory_info()

    c.execute(db.Insert(CPU_INFO_EMP).values(
        time=time.time(),
        voltage=core_voltage,
        clock=core_clock,
        temperature=core_temp,
        load=cpu_usage
    ))

    c.execute(db.Insert(WRITABLE_EMP).values(
        time=time.time(),
        ram_total=mem_phys,
        ram_left=mem_avail
    ))


def main():
    global ENGINE
    ENGINE = db.create_engine(f'sqlite:///main.db', echo=False)

    last = time.perf_counter() - INTERVAL
    while True:
        delta = INTERVAL - (time.perf_counter() - last)

        if delta > 0:
            time.sleep(delta)

        now = time.perf_counter()

        # write to database
        connection = ENGINE.connect()
        read(connection)
        connection.close()

        last = now


if __name__ == '__main__':
    main()
