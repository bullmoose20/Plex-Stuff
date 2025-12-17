import json
import os
import sys
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime
import glob
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

MAX_IMAGES = int(os.getenv("MAX_IMAGES", "50"))  # Default to 50 images if not specified
THRESHOLD = float(os.getenv("ANOMALY_THRESHOLD", "1.5"))  # Default is 1.5


def cleanup_images_directory(directory="images", max_images=MAX_IMAGES):
    """
    Limit the number of images in the directory to `max_images`.
    Delete the oldest files if the limit is exceeded.
    """
    if not os.path.exists(directory):
        return  # No action needed if the directory doesn't exist

    # Get all image files in the directory sorted by modification time
    image_files = sorted(
        glob.glob(os.path.join(directory, "*.png")),
        key=os.path.getmtime,
    )

    while len(image_files) > max_images:
        oldest_file = image_files.pop(0)
        os.remove(oldest_file)
        print(f"Deleted old image file: {oldest_file}")


# Load stats from the JSON file
def load_stats(file_path="stats/task_stats.json"):
    try:
        with open(file_path, "r") as file:
            data = json.load(file)
        return data
    except FileNotFoundError:
        print(f"Stats file '{file_path}' not found. Returning empty dataset.")
        sys.exit(1)  # Exit with an error code
    except json.JSONDecodeError as e:
        print(f"Failed to parse JSON in stats file '{file_path}': {e}. Returning empty dataset.")
        sys.exit(1)  # Exit with an error code


def setup_directories():
    """
    Create directories for logs, images, and stats if they don't exist.
    """
    os.makedirs("logs", exist_ok=True)
    os.makedirs("images", exist_ok=True)
    os.makedirs("stats", exist_ok=True)
    print("Directories set up: logs/, images/, stats/")


# Extract metrics for visualization
def extract_metrics(data):
    if not data:
        print("Error: No data available in the stats file. Exiting.")
        sys.exit(1)  # Exit if the data is empty

    loops = []
    total_times = []
    active_times = []
    maintenance_times = []
    task_stats = []

    for loop in data:
        loops.append(loop["loop"])
        total_times.append(
            sum(int(x) * 60 ** i for i, x in enumerate(reversed(loop["totals"]["total_task_time"].split(":"))))
        )
        active_times.append(
            sum(int(x) * 60 ** i for i, x in enumerate(reversed(loop["totals"]["total_active_time"].split(":"))))
        )
        maintenance_times.append(
            sum(int(x) * 60 ** i for i, x in enumerate(reversed(loop["totals"]["total_maintenance_time"].split(":"))))
        )
        task_stats.extend([
            {
                "loop": loop["loop"],
                "description": task["description"],
                "total_time": sum(int(x) * 60 ** i for i, x in enumerate(reversed(task["total_time"].split(":")))),
                "active_time": sum(int(x) * 60 ** i for i, x in enumerate(reversed(task["active_time"].split(":")))),
                "maintenance_time": sum(
                    int(x) * 60 ** i for i, x in enumerate(reversed(task["maintenance_time"].split(":")))),
            }
            for task in loop["tasks"]
        ])

    return loops, total_times, active_times, maintenance_times, task_stats


# Aggregate metrics
def calculate_aggregate_metrics(total_times, active_times, maintenance_times):
    if not total_times:
        print("Error: No data available to calculate aggregate metrics. Exiting.")
        sys.exit(1)  # Exit if no data is available
    return {
        "average_total_time": np.mean(total_times),
        "average_active_time": np.mean(active_times),
        "average_maintenance_time": np.mean(maintenance_times),
        "max_total_time": max(total_times),
        "min_total_time": min(total_times),
    }


# Per-task analysis
def per_task_analysis(task_stats):
    task_summaries = {}
    for task in task_stats:
        desc = task["description"]
        if desc not in task_summaries:
            task_summaries[desc] = {
                "total_time": [],
                "active_time": [],
                "maintenance_time": [],
            }
        task_summaries[desc]["total_time"].append(task["total_time"])
        task_summaries[desc]["active_time"].append(task["active_time"])
        task_summaries[desc]["maintenance_time"].append(task["maintenance_time"])
    return task_summaries


def format_time(seconds):
    hours, remainder = divmod(int(seconds), 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours:02}:{minutes:02}:{seconds:02}"


# Detect performance anomalies
def detect_anomalies(total_times, threshold=1.5):
    mean = np.mean(total_times)
    std_dev = np.std(total_times)
    anomalies = [i + 1 for i, time in enumerate(total_times) if abs(time - mean) > threshold * std_dev]

    # Log anomalies to a file
    if anomalies:
        anomaly_log_path = "logs/anomalies.log"
        with open(anomaly_log_path, "a") as file:
            file.write(f"{datetime.now().isoformat()} - Detected anomalies: {anomalies}\n")
        print(f"Anomalies logged in {anomaly_log_path}")

    return anomalies


def save_aggregate_metrics(aggregate_metrics):
    os.makedirs("stats", exist_ok=True)
    filepath = "stats/aggregate_metrics.json"
    with open(filepath, "w") as file:
        json.dump(aggregate_metrics, file, indent=4)
    print(f"Saved aggregate metrics to {filepath}")


# Create visualizations
def plot_metrics(loops, total_times, active_times, maintenance_times, aggregate_metrics, anomalies, stats):
    if not loops or not total_times:
        print("Error: No data available to generate metrics plot. Skipping visualization.")
        return  # Skip plotting

    plt.figure(figsize=(12, 6))

    # Plot loop time metrics
    plt.plot(loops, total_times, label="Total Time (seconds)", marker="o")
    plt.plot(loops, active_times, label="Active Time (seconds)", marker="o")
    plt.plot(loops, maintenance_times, label="Maintenance Time (seconds)", marker="o")

    # Highlight anomalies
    for anomaly in anomalies:
        plt.axvline(x=anomaly, color="red", linestyle="--", alpha=0.7, label=f"Anomaly at Loop {anomaly}")

    # Add aggregate metrics to the plot as annotations
    try:
        start_date = datetime.strptime(stats[0]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f").strftime("%b %d, %Y")
    except ValueError:
        start_date = datetime.strptime(stats[0]["timestamp"], "%Y-%m-%dT%H:%M:%S").strftime("%b %d, %Y")

    try:
        end_date = datetime.strptime(stats[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f").strftime("%b %d, %Y")
    except ValueError:
        end_date = datetime.strptime(stats[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S").strftime("%b %d, %Y")
    plt.title(f"Task Stats Over Loops ({start_date} to {end_date})")
    plt.xlabel("Loop Number")
    plt.ylabel("Time (seconds)")
    plt.legend()
    plt.grid()

    # Display aggregate metrics as text on the plot
    metrics_text = "\n".join([
        f"Avg Total: {format_time(aggregate_metrics['average_total_time'])}",
        f"Avg Active: {format_time(aggregate_metrics['average_active_time'])}",
        f"Avg Maintenance: {format_time(aggregate_metrics['average_maintenance_time'])}",
        f"Max Total: {format_time(aggregate_metrics['max_total_time'])}",
        f"Min Total: {format_time(aggregate_metrics['min_total_time'])}"
    ])

    plt.gcf().text(0.02, 0.5, metrics_text, fontsize=10, va="center",
                   bbox=dict(boxstyle="round", facecolor="white", alpha=0.5))

    # Save the plot to a file
    os.makedirs("images", exist_ok=True)
    filename = f"images/overall_metrics_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
    plt.savefig(filename)
    print(f"Saved overall metrics plot as {filename}")
    plt.show()


# Per-task visualization
def plot_per_task_analysis(task_summaries):
    plt.figure(figsize=(12, 8))
    tasks = list(task_summaries.keys())
    total_times = [np.mean(task_summaries[task]["total_time"]) for task in tasks]
    active_times = [np.mean(task_summaries[task]["active_time"]) for task in tasks]
    maintenance_times = [np.mean(task_summaries[task]["maintenance_time"]) for task in tasks]

    # Bar chart for per-task metrics
    x = np.arange(len(tasks))
    width = 0.25

    plt.bar(x - width, total_times, width, label="Total Time (avg)")
    plt.bar(x, active_times, width, label="Active Time (avg)")
    plt.bar(x + width, maintenance_times, width, label="Maintenance Time (avg)")

    plt.xlabel("Tasks")
    plt.ylabel("Time (seconds)")
    plt.title("Per-Task Analysis (Average Times)")
    plt.xticks(x, tasks, rotation=45, ha="right")
    plt.legend()
    plt.tight_layout()

    # Save the plot to a file
    os.makedirs("images", exist_ok=True)
    filename = f"images/per_task_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
    plt.savefig(filename)
    print(f"Saved per-task analysis plot as {filename}")
    plt.show()


# Main function to process data and visualize
def main():
    setup_directories()
    stats = load_stats()
    loops, total_times, active_times, maintenance_times, task_stats = extract_metrics(stats)
    aggregate_metrics = calculate_aggregate_metrics(total_times, active_times, maintenance_times)
    anomalies = detect_anomalies(total_times, threshold=THRESHOLD)
    task_summaries = per_task_analysis(task_stats)

    # Print aggregate metrics to the console
    print("\nAggregate Metrics:")
    for key, value in aggregate_metrics.items():
        print(f"  {key}: {value:.2f} seconds")

    # Plot overall metrics
    plot_metrics(loops, total_times, active_times, maintenance_times, aggregate_metrics, anomalies, stats)

    # Plot per-task analysis
    plot_per_task_analysis(task_summaries)

    # Save aggregate metrics
    save_aggregate_metrics(aggregate_metrics)

    # Optional: Cleanup old images directory
    cleanup_images_directory(directory="images", max_images=MAX_IMAGES)


if __name__ == "__main__":
    main()
