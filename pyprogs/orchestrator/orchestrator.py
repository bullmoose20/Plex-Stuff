# from multiprocessing import process
import os
import time
import psutil
from datetime import datetime, timedelta
import logging
import shutil
import subprocess
from plexapi.server import PlexServer
from dotenv import load_dotenv
import requests
from qbittorrentapi import Client, LoginFailed, APIConnectionError
import yaml
import argparse
import json
from pathlib import Path

# Load environment variables
load_dotenv()

RUNNING_PROCESSES = set()
PAUSED_PROCESSES = set()
SHUTDOWN_FLAG = False

# For testing maintenance times,
# In UNIX: "touch mock.flg", "rm mock.flg"
# In powershell: "New-Item -ItemType File -Name mock.flg", "Remove-Item mock.flg"
MOCK_FLAG_FILE = os.getenv("MOCK_FLAG_FILE", "mock.flg")  # Default: "mock.flg"
LOG_EVERY_N_CHECKS = int(os.getenv("LOG_EVERY_N_CHECKS", 12))  # Default: 12
LOG_DIVIDER = os.getenv("LOG_DIVIDER", "=") * 80  # Default: 80 equals
TASK_DIVIDER = os.getenv("TASK_DIVIDER", "*") * 80  # Default: 80 asterisks
MAX_LOGS = os.getenv("MAX_LOGS", "5")

# Get .env configuration
PLEX_URL = os.getenv("PLEX_URL")
PLEX_TOKEN = os.getenv("PLEX_TOKEN")
SONARR_URL = os.getenv("SONARR_URL")
SONARR_API_KEY = os.getenv("SONARR_API_KEY")
RADARR_URL = os.getenv("RADARR_URL")
RADARR_API_KEY = os.getenv("RADARR_API_KEY")
LIDARR_URL = os.getenv("LIDARR_URL")
LIDARR_API_KEY = os.getenv("LIDARR_API_KEY")
QBITTORRENT_URL = os.getenv("QBITTORRENT_URL", "http://localhost:6881/")
QBITTORRENT_USERNAME = os.getenv("QBITTORRENT_USERNAME", "admin")
QBITTORRENT_PASSWORD = os.getenv("QBITTORRENT_PASSWORD", "adminadmin")
SABNZBD_URL = os.getenv("SABNZBD_URL", "http://localhost:8080/")
SABNZBD_API_KEY = os.getenv("SABNZBD_API_KEY", "the_key")
NZBGET_URL = os.getenv("NZBGET_URL", "http://localhost:6789")
NZBGET_USERNAME = os.getenv("NZBGET_USERNAME", "nzbget")
NZBGET_PASSWORD = os.getenv("NZBGET_PASSWORD", "tegbzn6789")


# === Helper Functions ===

def execute_task(task, start, end, loop_count=None, current_task_idx=None, total_tasks=None, loop_start_mon=None):
    """Execute a task and return its duration and maintenance time."""
    log_and_print(f"Executing task: {task.get('description')}", "info")
    try:
        if "script_path" in task:  # For script-based tasks
            return run_script_with_context(
                task["script_path"],
                task["args"],
                start,
                end,
                use_venv=task.get("use_venv"),
                loop_count=loop_count,
                current_task_idx=current_task_idx,
                total_tasks=total_tasks,
                loop_start_mon=loop_start_mon,
            )

        elif "action" in task:  # For Python function-based tasks
            action_function = globals().get(task["action"])
            if not action_function:
                raise ValueError(f"Unknown action: {task['action']}")
            return ensure_return_value(action_function)
    except Exception as e:
        log_and_print(f"Error executing task '{task.get('description')}': {e}", "error")
        return 0, 0  # Return fallback values


def ensure_return_value(func, *args, **kwargs):
    """Ensure that a task function returns a tuple (task_duration, maintenance_time)."""
    result = func(*args, **kwargs)
    if result is None:
        return (0, 0)  # Default values
    return result


def setup_logging(max_logs=5):
    """
    Configure logging to rotate logs with a timestamp in the 'logs/' directory.
    """
    max_logs = int(max_logs)

    # Ensure logs directory exists
    log_dir = "logs"
    os.makedirs(log_dir, exist_ok=True)

    # Get the current script name without extension
    script_name = os.path.splitext(os.path.basename(__file__))[0]
    current_log_file = os.path.join(log_dir, f"{script_name}.log")

    # Generate a timestamp for the rotated log
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    rotated_log_file = os.path.join(log_dir, f"{script_name}_{timestamp}.log")

    # Rotate the log file if it exists
    if os.path.exists(current_log_file):
        os.rename(current_log_file, rotated_log_file)

    # Limit the number of log files to max_logs
    log_files = sorted(
        [
            os.path.join(log_dir, f)
            for f in os.listdir(log_dir)
            if f.startswith(script_name) and f.endswith(".log")
        ],
        key=os.path.getmtime,
    )

    while len(log_files) > max_logs - 1:  # Keep max_logs - 1 old logs + 1 current log
        os.remove(log_files.pop(0))

    # Set up logging
    logging.basicConfig(
        filename=current_log_file,
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )

    logging.info("Rotated log file to %s", rotated_log_file)
    logging.info("Logging started in %s", current_log_file)


def format_time(seconds):
    """Convert seconds into a human-readable HH:MM:SS format."""
    hours, remainder = divmod(int(seconds), 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours:02}:{minutes:02}:{seconds:02}"


def elapsed_str(start_monotonic: float) -> str:
    """Return HH:MM:SS elapsed since start_monotonic (monotonic clock)."""
    return format_time(time.monotonic() - start_monotonic)


def setup_directories():
    """
    Create directories for logs, images, and stats if they don't exist.
    """
    os.makedirs("logs", exist_ok=True)
    os.makedirs("images", exist_ok=True)
    os.makedirs("stats", exist_ok=True)
    log_and_print("Directories set up: logs/, images/, stats/", "info")


def connect_to_plex(retries=3, delay=5):
    """Attempt to connect to the Plex server with retries."""
    if not PLEX_URL or not PLEX_TOKEN:
        log_and_print("Plex URL or token not set. Cannot connect to Plex server.", "error")
        return None

    for attempt in range(1, retries + 1):
        try:
            log_and_print(f"Attempting to connect to Plex server (Attempt {attempt}/{retries})...", "info")
            return PlexServer(PLEX_URL, PLEX_TOKEN)
        except Exception as e:
            log_and_print(f"Failed to connect to Plex server: {e}", "error")
            if attempt < retries:
                log_and_print(f"Retrying in {delay} seconds...", "info")
                time.sleep(delay)
            else:
                log_and_print("All connection attempts failed.", "error")
    return None


def log_and_continue(action_name, func, *args, **kwargs):
    """
    Execute a function, log any errors, and continue execution.
    """
    try:
        func(*args, **kwargs)
    except Exception as e:
        log_and_print(f"Error during {action_name}: {e}", "error")


def log_and_print(message, level="info"):
    """
    Log and print a message to the console.
    """
    getattr(logging, level)(message)  # Log the message
    print(message)  # Print to the console


def log_process_tree_with_delay(parent_pid, delay=2.0):
    """
    Log the parent and child process tree for a given parent PID after a short delay.
    """
    try:
        time.sleep(delay)  # Allow child processes to start
        parent = psutil.Process(parent_pid)
        log_and_print(f"Parent process: PID {parent.pid}, Name: {parent.name()}", "info")

        for child in parent.children(recursive=True):
            log_and_print(f"Child process: PID {child.pid}, Name: {child.name()}", "info")
    except psutil.NoSuchProcess:
        log_and_print(f"Parent process {parent_pid} no longer exists.", "warning")


def run_task_with_pause_check(command, start, end, loop_count=None, current_task_idx=None, total_tasks=None, loop_start_mon=None):
    # Set default values if None
    loop_count = loop_count or "?"
    current_task_idx = current_task_idx or "?"
    total_tasks = total_tasks or "?"
    task_start_mon = time.monotonic()
    run_task_with_pause_check._tick = 0

    log_and_print(TASK_DIVIDER, "info")
    loop_elapsed = elapsed_str(loop_start_mon) if loop_start_mon else "??:??:??"
    task_elapsed = elapsed_str(task_start_mon)

    task_info = f"Loop {loop_count} - Task {current_task_idx} / {total_tasks}"
    log_and_print(
        f"{task_info} (Loop Elapsed: {loop_elapsed}, Task Elapsed {task_elapsed}): "
        f"Starting task: {' '.join(command)}",
        "info"
    )

    process = subprocess.Popen(command)
    RUNNING_PROCESSES.add(process.pid)
    PAUSED_PROCESSES.discard(process.pid)
    maintenance_time = 0
    task_start_time = time.time()

    try:
        log_process_tree_with_delay(process.pid, delay=0.1)

        while process.poll() is None:
            if is_maintenance_time(start, end, loop_count, current_task_idx, total_tasks):
                loop_elapsed = elapsed_str(loop_start_mon) if loop_start_mon else "??:??:??"
                task_elapsed = elapsed_str(task_start_mon)

                log_and_print(
                    f"{task_info} (Loop Elapsed: {loop_elapsed}, Task Elapsed {task_elapsed}): "
                    f"Maintenance detected. Pausing task...",
                    "info"
                    )
                pause_start = time.time()
                pause_process(process.pid)

                while is_maintenance_time(start, end, loop_count, current_task_idx, total_tasks):
                    loop_elapsed = elapsed_str(loop_start_mon) if loop_start_mon else "??:??:??"
                    task_elapsed = elapsed_str(task_start_mon)

                    log_and_print(
                        f"{task_info} (Loop Elapsed: {loop_elapsed}, Task Elapsed {task_elapsed}): "
                        f"Still within the maintenance window. Waiting...",
                        "info"
                    )
                    time.sleep(10)

                pause_end = time.time()
                maintenance_time += pause_end - pause_start
                log_and_print(f"{task_info}: Maintenance ended. Resuming task...", "info")
                resume_process(process.pid)

            run_task_with_pause_check._tick += 1

            if run_task_with_pause_check._tick >= LOG_EVERY_N_CHECKS:
                run_task_with_pause_check._tick = 0
                loop_elapsed = elapsed_str(loop_start_mon) if loop_start_mon else "??:??:??"
                task_elapsed = elapsed_str(task_start_mon)
                log_and_print(
                    f"{task_info} (Loop Elapsed: {loop_elapsed}, Task Elapsed {task_elapsed}): "
                    f"Task still running...",
                    "info"
                )

            time.sleep(5)

    except KeyboardInterrupt:
        log_and_print("Ctrl-C detected. Terminating subprocess...", "warning")
        process.terminate()
        process.wait()
        raise  # Re-raise to propagate exit signal
    except Exception as e:
        log_and_print(f"Error during task execution: {e}", "error")
        process.terminate()
        process.wait()
        return 0, maintenance_time  # Provide fallback values

    finally:
        # Ensure the process is terminated if still running
        RUNNING_PROCESSES.discard(process.pid)
        PAUSED_PROCESSES.discard(process.pid)
        if process.poll() is None:
            process.terminate()
            process.wait()

    # Calculate task duration excluding maintenance time
    task_end_time = time.time()
    task_duration = task_end_time - task_start_time

    log_and_print(f"{task_info}: Task completed.", "info")
    log_and_print(f"Total time: {format_time(task_duration)}", "info")
    log_and_print(f"Active task time (excluding maintenance): {format_time(task_duration - maintenance_time)}", "info")
    log_and_print(f"Total maintenance time: {format_time(maintenance_time)}", "info")
    # log_and_print(f"Returning values: Task Duration: {task_duration}, Maintenance Time: {maintenance_time}", "info")

    return task_duration, maintenance_time


def get_plex_maintenance_window():
    """Get Plex's built-in maintenance window (Butler settings)."""
    if not plex:
        log_and_print("Plex server is not connected. Cannot retrieve maintenance window.", "error")
        return None, None

    try:
        srv_settings = plex.settings
        butler_start = srv_settings.get("butlerStartHour").value
        butler_end = srv_settings.get("butlerEndHour").value
        start_time = f"{int(butler_start):02d}:00"  # Format as HH:MM
        end_time = f"{int(butler_end):02d}:00"      # Format as HH:MM
        log_and_print(f"Scheduled maintenance: {start_time} to {end_time}", "info")
        return start_time, end_time
    except Exception as e:
        log_and_print(f"Failed to get maintenance window: {e}", "error")
        return None, None


def is_mock_maintenance_enabled():
    """
    Check for the presence of the mock flag file (case-insensitive) in the orchestrator's directory
    and dynamically adjust the mock maintenance period.
    """
    now = datetime.now()
    script_dir = os.path.dirname(os.path.abspath(__file__))  # Directory where orchestrator.py is located

    # Check for the presence of mock.flg case-insensitively in the script directory
    for file in os.listdir(script_dir):
        if file.lower() == MOCK_FLAG_FILE.lower():
            # Set the maintenance window to extend dynamically
            start_time = now
            end_time = now + timedelta(seconds=120)  # Extend by 120 seconds each check
            # log_and_print(f"Mock maintenance active. Window: {start_time.time()} to {end_time.time()}", "info")
            return start_time, end_time

    # log_and_print("Mock maintenance not active.", "info")
    return None, None


def is_maintenance_time(start, end, loop_count=None, current_task_idx=None, total_tasks=None):
    now = datetime.now()
    loop_count = loop_count or "?"
    current_task_idx = current_task_idx or "?"
    total_tasks = total_tasks or "?"

    task_info = f"Loop {loop_count} - Task {current_task_idx} / {total_tasks}"

    mock_start, mock_end = is_mock_maintenance_enabled()
    if mock_start and mock_end:
        in_maintenance = mock_start <= now <= mock_end
        current_status = "mock_maintenance" if in_maintenance else "no_maintenance"
    else:
        try:
            now_time = now.time()
            start_time = datetime.strptime(start, "%H:%M").time()
            end_time = datetime.strptime(end, "%H:%M").time()
            in_maintenance = start_time <= now_time <= end_time
            current_status = "real_maintenance" if in_maintenance else "no_maintenance"
        except Exception as e:
            log_and_print(f"{task_info}: Error checking maintenance time: {e}", "error")
            return False

    # Log status changes
    if not hasattr(is_maintenance_time, "_state"):
        is_maintenance_time._state = {"last_status": None, "log_counter": 0}

    if current_status != is_maintenance_time._state["last_status"]:
        is_maintenance_time._state["last_status"] = current_status
        is_maintenance_time._state["log_counter"] = 0
        if in_maintenance:
            log_and_print(f"{task_info}: Entered maintenance window.", "info")
        else:
            log_and_print(f"{task_info}: Outside maintenance window.", "info")
    return in_maintenance


def get_child_processes(parent_pid):
    """
    Get all child processes for a given parent PID.
    """
    try:
        parent = psutil.Process(parent_pid)
        return parent.children(recursive=True)  # Recursively fetch all child processes
    except psutil.NoSuchProcess:
        return []


def pause_process(pid):
    try:
        process = psutil.Process(pid)
        process.suspend()
        PAUSED_PROCESSES.add(pid)
        RUNNING_PROCESSES.discard(pid)
        log_and_print(f"Paused process {pid}.", "info")

        for child in get_child_processes(pid):
            child.suspend()
            PAUSED_PROCESSES.add(child.pid)
            RUNNING_PROCESSES.discard(child.pid)
            log_and_print(f"Paused child process {child.pid}.", "info")
    except Exception as e:
        log_and_print(f"Failed to pause process {pid}: {e}", "error")


def resume_process(pid):
    try:
        process = psutil.Process(pid)
        process.resume()
        PAUSED_PROCESSES.discard(pid)
        RUNNING_PROCESSES.add(pid)
        log_and_print(f"Resumed process {pid}.", "info")

        for child in get_child_processes(pid):
            child.resume()
            PAUSED_PROCESSES.discard(child.pid)
            RUNNING_PROCESSES.add(child.pid)
            log_and_print(f"Resumed child process {child.pid}.", "info")
    except Exception as e:
        log_and_print(f"Failed to resume process {pid}: {e}", "error")


# === Sonarr Functions ===

def disable_sonarr_download_clients():
    """Disable all downloaders in Sonarr."""
    log_and_print("Disabling Sonarr downloaders...", "info")
    url = f"{SONARR_URL}/api/v3/downloadclient"
    headers = {"X-Api-Key": SONARR_API_KEY}

    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        log_and_print(f"Failed to retrieve downloaders: {response.status_code} {response.text}", "error")
        return

    clients = response.json()
    for client in clients:
        client_id = client.get("id")
        client_name = client.get("name")

        if not client.get("enable"):
            log_and_print(f"Downloader {client_name} is already disabled.", "info")
            continue

        # Include all fields in the payload
        disable_url = f"{url}/{client_id}"
        payload = {
            **client,  # Copy all fields from the current client
            "enable": False  # Explicitly set enable to False
        }

        update_response = requests.put(disable_url, json=payload, headers=headers)
        if update_response.status_code in (200, 202):
            log_and_print(f"Disabled downloaders: {client_name}", "info")
        else:
            log_and_print(f"Failed to disable {client_name}: {update_response.status_code} {update_response.text}", "error")


def enable_sonarr_download_clients():
    """Enable all downloaders in Sonarr."""
    log_and_print("Enabling Sonarr downloaders...", "info")
    url = f"{SONARR_URL}/api/v3/downloadclient"
    headers = {"X-Api-Key": SONARR_API_KEY}

    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        log_and_print(f"Failed to retrieve downloaders: {response.status_code} {response.text}", "error")
        return

    clients = response.json()
    for client in clients:
        client_id = client.get("id")
        client_name = client.get("name")

        if client.get("enable"):
            log_and_print(f"Downloader {client_name} is already enabled.", "info")
            continue

        # Include all fields in the payload
        enable_url = f"{url}/{client_id}"
        payload = {
            **client,  # Copy all fields from the current client
            "enable": True  # Explicitly set enable to True
        }

        update_response = requests.put(enable_url, json=payload, headers=headers)
        if update_response.status_code in (200, 202):
            log_and_print(f"Enabled downloaders: {client_name}", "info")
        else:
            log_and_print(f"Failed to enable {client_name}: {update_response.status_code} {update_response.text}", "error")

# === Radarr Functions ===


def disable_radarr_download_clients():
    """Disable all downloaders in Radarr."""
    log_and_print("Disabling Radarr downloaders...", "info")
    url = f"{RADARR_URL}/api/v3/downloadclient"
    headers = {"X-Api-Key": RADARR_API_KEY}

    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        log_and_print(f"Failed to retrieve downloaders: {response.status_code} {response.text}", "error")
        return

    clients = response.json()
    for client in clients:
        client_id = client.get("id")
        client_name = client.get("name")

        if not client.get("enable"):
            log_and_print(f"Downloader {client_name} is already disabled.", "info")
            continue

        # Include all fields in the payload
        disable_url = f"{url}/{client_id}"
        payload = {
            **client,  # Copy all fields from the current client
            "enable": False  # Explicitly set enable to False
        }

        update_response = requests.put(disable_url, json=payload, headers=headers)
        if update_response.status_code in (200, 202):
            log_and_print(f"Disabled downloaders: {client_name}", "info")
        else:
            log_and_print(f"Failed to disable {client_name}: {update_response.status_code} {update_response.text}", "error")


def enable_radarr_download_clients():
    """Enable all downloaders in Radarr."""
    log_and_print("Enabling Radarr downloaders...", "info")
    url = f"{RADARR_URL}/api/v3/downloadclient"
    headers = {"X-Api-Key": RADARR_API_KEY}

    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        log_and_print(f"Failed to retrieve downloaders: {response.status_code} {response.text}", "error")
        return

    clients = response.json()
    for client in clients:
        client_id = client.get("id")
        client_name = client.get("name")

        if client.get("enable"):
            log_and_print(f"Downloader {client_name} is already enabled.", "info")
            continue

        # Include all fields in the payload
        enable_url = f"{url}/{client_id}"
        payload = {
            **client,  # Copy all fields from the current client
            "enable": True  # Explicitly set enable to True
        }

        update_response = requests.put(enable_url, json=payload, headers=headers)
        if update_response.status_code in (200, 202):
            log_and_print(f"Enabled downloaders: {client_name}", "info")
        else:
            log_and_print(f"Failed to enable {client_name}: {update_response.status_code} {update_response.text}", "error")


# === Lidarr Functions ===

def disable_lidarr_download_clients():
    """Disable all downloaders in Lidarr."""
    log_and_print("Disabling Lidarr downloaders...", "info")
    url = f"{LIDARR_URL}/api/v1/downloadclient"
    headers = {"X-Api-Key": LIDARR_API_KEY}

    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        log_and_print(f"Failed to retrieve downloaders: {response.status_code} {response.text}", "error")
        return

    clients = response.json()
    for client in clients:
        client_id = client.get("id")
        client_name = client.get("name")

        if not client.get("enable"):
            log_and_print(f"Downloader {client_name} is already disabled.", "info")
            continue

        # Include all fields in the payload
        disable_url = f"{url}/{client_id}"
        payload = {
            **client,  # Copy all fields from the current client
            "enable": False  # Explicitly set enable to False
        }

        update_response = requests.put(disable_url, json=payload, headers=headers)
        if update_response.status_code in (200, 202):
            log_and_print(f"Disabled downloaders: {client_name}", "info")
        else:
            log_and_print(f"Failed to disable {client_name}: {update_response.status_code} {update_response.text}", "error")


def enable_lidarr_download_clients():
    """Enable all downloaders in Lidarr."""
    log_and_print("Enabling Lidarr downloaders...", "info")
    url = f"{LIDARR_URL}/api/v1/downloadclient"
    headers = {"X-Api-Key": LIDARR_API_KEY}

    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        log_and_print(f"Failed to retrieve downloaders: {response.status_code} {response.text}", "error")
        return

    clients = response.json()
    for client in clients:
        client_id = client.get("id")
        client_name = client.get("name")

        if client.get("enable"):
            log_and_print(f"Downloader {client_name} is already enabled.", "info")
            continue

        # Include all fields in the payload
        enable_url = f"{url}/{client_id}"
        payload = {
            **client,  # Copy all fields from the current client
            "enable": True  # Explicitly set enable to True
        }

        update_response = requests.put(enable_url, json=payload, headers=headers)
        if update_response.status_code in (200, 202):
            log_and_print(f"Enabled downloaders: {client_name}", "info")
        else:
            log_and_print(f"Failed to enable {client_name}: {update_response.status_code} {update_response.text}", "error")


# === Download Client Functions ===


def connect_to_qbittorrent():
    """Connect to the qBittorrent API using the provided environment variables."""
    try:
        client = Client(
            host=QBITTORRENT_URL,
            username=QBITTORRENT_USERNAME,
            password=QBITTORRENT_PASSWORD
        )
        logging.info("Connected to qBittorrent successfully.")
        return client
    except LoginFailed:
        logging.error("Failed to log in to qBittorrent. Check username/password.")
        raise
    except APIConnectionError:
        logging.error("Unable to connect to qBittorrent. Check URL/API availability.")
        raise
    except Exception as e:
        logging.error(f"Unexpected error connecting to qBittorrent: {e}")
        raise


def pause_qbittorrent_downloads():
    """Pause all active downloads in qBittorrent using qbittorrent-api."""
    log_and_continue(
        "Pausing qBittorrent downloads",
        _pause_qbittorrent_torrents
    )


def resume_qbittorrent_downloads():
    """Resume all paused downloads in qBittorrent using qbittorrent-api."""
    log_and_continue(
        "Resuming qBittorrent downloads",
        _resume_qbittorrent_torrents
    )


def _pause_qbittorrent_torrents():
    """Helper function to perform the pause operation."""
    client = connect_to_qbittorrent()
    client.torrents.pause(hashes="all")  # Pause all torrents
    logging.info("Successfully paused all torrents in qBittorrent.")


def _resume_qbittorrent_torrents():
    """Helper function to perform the resume operation."""
    client = connect_to_qbittorrent()
    client.torrents.resume(hashes="all")  # Resume all torrents
    logging.info("Successfully resumed all torrents in qBittorrent.")


def pause_sabnzbd_downloads():
    """Pause all active downloads in SABnzbd."""
    log_and_print("Pausing SABnzbd downloads...", "info")
    pause_response = requests.get(f"{SABNZBD_URL}/api?mode=pause&apikey={SABNZBD_API_KEY}")
    if pause_response.status_code != 200:
        raise Exception(f"Failed to pause SABnzbd downloads: {pause_response.text}")


def resume_sabnzbd_downloads():
    """Resume all paused downloads in SABnzbd."""
    log_and_print("Resuming SABnzbd downloads...", "info")
    resume_response = requests.get(f"{SABNZBD_URL}/api?mode=resume&apikey={SABNZBD_API_KEY}")
    if resume_response.status_code != 200:
        raise Exception(f"Failed to resume SABnzbd downloads: {resume_response.text}")


def pause_nzbget_downloads():
    """Pause all active downloads in NZBGet."""
    log_and_print("Pausing NZBGet downloads...", "info")
    pause_response = requests.get(
        f"{NZBGET_URL}/jsonrpc",
        auth=(NZBGET_USERNAME, NZBGET_PASSWORD),
        json={"method": "pausedownload"}
    )
    if pause_response.status_code != 200:
        raise Exception(f"Failed to pause NZBGet downloads: {pause_response.text}")


def resume_nzbget_downloads():
    """Resume all paused downloads in NZBGet."""
    log_and_print("Resuming NZBGet downloads...", "info")
    resume_response = requests.get(
        f"{NZBGET_URL}/jsonrpc",
        auth=(NZBGET_USERNAME, NZBGET_PASSWORD),
        json={"method": "resumedownload"}
    )
    if resume_response.status_code != 200:
        raise Exception(f"Failed to resume NZBGet downloads: {resume_response.text}")


def run_script_with_context(script_path, args, start, end, use_venv=None,
                            loop_count=None, current_task_idx=None, total_tasks=None,
                            loop_start_mon=None):
    loop_count = loop_count or "?"
    current_task_idx = current_task_idx or "?"
    total_tasks = total_tasks or "?"

    task_info = f"Loop {loop_count} - Task {current_task_idx} / {total_tasks}"
    log_and_print(f"{task_info}: Running script '{script_path}' with arguments {args}", "info")

    # Change to the script's directory
    script_dir = os.path.dirname(script_path)
    script_name = os.path.basename(script_path)
    log_and_print(TASK_DIVIDER, "info")
    log_and_print(f"Running script '{script_name}' from directory '{script_dir}' with arguments {args}", "info")

    original_dir = os.getcwd()
    os.chdir(script_dir)

    try:
        # Construct the command based on script type
        if script_name.endswith(".py"):
            command = ["python", script_name] + args
            if use_venv:
                activate_venv = os.path.join(use_venv, "Scripts", "activate.bat")
                command = [
                    "cmd.exe",
                    "/c",
                    f"{activate_venv} && python {script_name} {' '.join(args)}"
                ]
        elif script_name.endswith(".ps1"):
            pwsh = shutil.which("pwsh")
            ps = pwsh if pwsh else "powershell"

            command = [
                ps,
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", script_name
            ] + args

        else:
            raise ValueError(f"Unsupported script type: {script_name}. Only .py and .ps1 are supported.")

        log_and_print(TASK_DIVIDER, "info")
        log_and_print(f"Starting task with command: {' '.join(command)}", "info")

        # Run the task and return the results
        return run_task_with_pause_check(
            command,
            start,
            end,
            loop_count=loop_count,
            current_task_idx=current_task_idx,
            total_tasks=total_tasks,
            loop_start_mon=loop_start_mon,
        )
    except Exception as e:
        log_and_print(f"Error while running script '{script_name}': {e}", "error")
        return 0, 0  # Return fallback values in case of an exception
    finally:
        os.chdir(original_dir)


# === Main Orchestration ===

def monitor_maintenance_and_tasks(config_file):
    """Orchestrate maintenance and tasks based on configuration."""
    try:
        config = validate_and_load_config(config_file)
        tasks = config.get("tasks", [])
        loop_count = 0

        while True:
            loop_count += 1
            log_and_print(f"Starting Loop {loop_count}...", "info")

            loop_start_mon = time.monotonic()
            total_maintenance_time = 0
            total_active_time = 0
            total_task_time = 0
            task_summaries = []
            start, end = get_plex_maintenance_window()

            for idx, task in enumerate(tasks, start=1):
                task_progress = f"Loop {loop_count} - Task {idx} / {len(tasks)}: {task.get('description')}"
                log_and_print(task_progress, "info")

                try:
                    task_duration, maintenance_time = execute_task(
                        task,
                        start,
                        end,
                        loop_count=loop_count,
                        current_task_idx=idx,
                        total_tasks=len(tasks),
                        loop_start_mon=loop_start_mon
                    )
                    active_time = task_duration - maintenance_time
                    total_maintenance_time += maintenance_time
                    total_active_time += active_time
                    total_task_time += task_duration

                    task_summaries.append({
                        "index": idx,
                        "description": task.get("description"),
                        "total_time": format_time(task_duration),
                        "active_time": format_time(active_time),
                        "maintenance_time": format_time(maintenance_time),
                    })
                except Exception as e:
                    log_and_print(f"Error during Task {idx}: {e}", "error")
                    task_duration, maintenance_time = 0, 0

            # Log detailed task summaries
            log_and_print(LOG_DIVIDER, "info")
            log_and_print(f"Loop {loop_count} Summary:", "info")
            for task_summary in task_summaries:
                log_and_print(
                    f"  Task {task_summary['index']}/{len(tasks)}: {task_summary['description']} - "
                    f"Total Time: {task_summary['total_time']}, "
                    f"Active Time: {task_summary['active_time']}, "
                    f"Maintenance Time: {task_summary['maintenance_time']}",
                    "info"
                )

            # Log overall summary
            log_and_print("Overall Loop Summary:", "info")
            log_and_print(f"  Total Tasks: {len(tasks)}", "info")
            log_and_print(f"  Total Loop Time (including maintenance): {format_time(total_task_time)}", "info")
            log_and_print(f"  Total Loop Time (excluding maintenance): {format_time(total_active_time)}", "info")
            log_and_print(f"  Total Maintenance Time: {format_time(total_maintenance_time)}", "info")
            log_and_print(LOG_DIVIDER, "info")
            save_loop_stats(
                loop_count,
                task_summaries,
                total_task_time,
                total_active_time,
                total_maintenance_time
            )

            # Delay before next loop
            log_and_print(f"Loop {loop_count} - All tasks completed. Restarting the loop after a delay...", "info")
            time.sleep(60)
    except KeyboardInterrupt:
        log_and_print("Ctrl-C detected. Exiting script...", "warning")


def delete_temp_files(config_file):
    """
    Delete specific temporary files if they exist, based on the tasks configuration.
    """
    # Load tasks from the configuration file
    tasks_config = validate_and_load_config(config_file)

    # Extract script directories from tasks configuration
    script_dirs = []
    for task in tasks_config.get("tasks", []):  # Ensure "tasks" key exists in the config
        if "script_path" in task:
            script_dir = os.path.dirname(task["script_path"])
            script_dirs.append(script_dir)

    # Define the temp file paths to check
    temp_files = [
        os.path.join(script_dir, "temp", "Posterizarr.Running")
        for script_dir in script_dirs
    ]

    # Check and delete temp files
    for file_path in temp_files:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                log_and_print(f"Deleted temporary file: {file_path}", "info")
            else:
                log_and_print(f"Temporary file not found, skipping: {file_path}", "info")
        except Exception as e:
            log_and_print(f"Error deleting file {file_path}: {e}", "error")


def terminate_all_processes():
    """Terminate all running and paused processes."""
    log_and_print("Terminating all subprocesses...", "warning")
    for pid in list(RUNNING_PROCESSES | PAUSED_PROCESSES):
        try:
            process = psutil.Process(pid)
            log_and_print(f"Terminating process {pid} ({process.name()}).", "info")
            process.terminate()  # Send termination signal
            process.wait(timeout=5)  # Wait for process to terminate
        except psutil.NoSuchProcess:
            log_and_print(f"Process {pid} already terminated.", "info")
        except Exception as e:
            log_and_print(f"Error terminating process {pid}: {e}", "error")
    # Clear the sets
    RUNNING_PROCESSES.clear()
    PAUSED_PROCESSES.clear()


def load_config(file_path):
    """Load tasks configuration from a YAML file."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Configuration file not found: {file_path}")
    try:
        with open(file_path, "r") as file:
            config = yaml.safe_load(file)
            if not config:
                raise ValueError("Configuration file is empty or invalid.")
            return config
    except yaml.YAMLError as e:
        raise ValueError(f"Failed to parse YAML file: {file_path}. Error: {e}")


def validate_and_load_config(config_file=None):
    """
    Validate and load the configuration file.
    - Use 'tasks.yml' by default if no config file is provided.
    - Validate the existence and structure of the config file.
    """
    if not config_file:
        config_file = "tasks.yml"  # Default file

    log_and_print(f"Using configuration file: {config_file}", "info")

    try:
        config = load_config(config_file)  # Load the YAML file
        tasks = config.get("tasks", [])
        validate_tasks_config(tasks)  # Validate the structure of tasks
        return config
    except Exception as e:
        raise ValueError(f"Error in configuration file {config_file}: {e}")


def validate_tasks_config(tasks):
    """Validate the structure of the tasks in the configuration."""
    for idx, task in enumerate(tasks, start=1):
        if "description" not in task:
            raise ValueError(f"Task {idx} is missing 'description'.")
        if not ("script_path" in task or "action" in task):
            raise ValueError(f"Task {idx} must include either 'script_path' or 'action'.")
        if "script_path" in task and not isinstance(task["script_path"], str):
            raise ValueError(f"Task {idx}: 'script_path' must be a string.")
        if "args" in task and not isinstance(task["args"], list):
            raise ValueError(f"Task {idx}: 'args' must be a list.")
        if "use_venv" in task and task["use_venv"] is not None and not isinstance(task["use_venv"], str):
            raise ValueError(f"Task {idx}: 'use_venv' must be a string or null.")


def save_loop_stats(loop_count, task_summaries, total_task_time, total_active_time, total_maintenance_time):
    stats_file = "stats/task_stats.json"
    data = {
        "loop": loop_count,
        "timestamp": datetime.now().isoformat(),
        "tasks": task_summaries,
        "totals": {
            "total_tasks": len(task_summaries),
            "total_task_time": format_time(total_task_time),
            "total_active_time": format_time(total_active_time),
            "total_maintenance_time": format_time(total_maintenance_time),
        },
    }

    # Append to stats file
    stats_path = Path(stats_file)
    if stats_path.exists():
        with open(stats_file, "r") as file:
            existing_data = json.load(file)
            existing_data.append(data)
    else:
        existing_data = [data]

    with open(stats_file, "w") as file:
        json.dump(existing_data, file, indent=4)
    log_and_print(f"Saved loop stats to {stats_file}", "info")


def main():
    try:
        setup_directories()
        log_and_print(LOG_DIVIDER, "info")
        log_and_print("Script started.", "info")

        # Connect to Plex
        global plex
        plex = connect_to_plex()

        if not plex:
            log_and_print("Plex connection failed. Exiting script.", "error")
            return

        delete_temp_files(args.config)
        monitor_maintenance_and_tasks(args.config)
    except KeyboardInterrupt:
        log_and_print("Ctrl-C detected. Exiting script and cleaning up...", "warning")
    except Exception as e:
        log_and_print(f"Unhandled exception: {e}", "error")
    finally:
        log_and_print("Performing cleanup: Resuming all paused services and downloads.", "info")
        try:
            delete_temp_files(args.config)
            terminate_all_processes()
            # Ensure all paused services and downloads are resumed
            log_and_continue("enable Sonarr downloaders", enable_sonarr_download_clients)
            log_and_continue("enable Radarr downloaders", enable_radarr_download_clients)
            log_and_continue("enable Lidarr downloaders", enable_lidarr_download_clients)
            log_and_continue("resume qBittorrent", resume_qbittorrent_downloads)
            log_and_continue("resume SABnzbd", resume_sabnzbd_downloads)
            log_and_continue("resume NZBGet", resume_nzbget_downloads)
        except Exception as e:
            log_and_print(f"Error during cleanup: {e}", "error")
        log_and_print(LOG_DIVIDER, "info")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Orchestrator Script")
    parser.add_argument("--config", help="Path to tasks configuration file", default="tasks.yml")

    args = parser.parse_args()

    max_logs = int(os.getenv("MAX_LOGS", "5"))
    setup_logging(max_logs)
    main()
