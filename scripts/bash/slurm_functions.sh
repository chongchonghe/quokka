#!/bin/bash

# Function to kill pending SLURM jobs containing a specific jobname
# Usage: kill_jobs <jobname>
kill_jobs() {
    local jobname="$1"

    if [[ -z "$jobname" ]]; then
        echo "Error: Please provide a jobname to search for"
        echo "Usage: kill_jobs <jobname>"
        return 1
    fi

    # Get list of pending jobs for current user that contain the jobname
    local pending_jobs
    pending_jobs=$(squeue -u "$USER" -t PD -h -o "%i %j" | grep -i "$jobname" | awk '{print $1 ":" $2}')

    if [[ -z "$pending_jobs" ]]; then
        echo "No pending jobs found containing '$jobname'"
        return 0
    fi

    echo "Found the following pending jobs containing '$jobname':"
    echo "$pending_jobs" | while IFS=: read -r jobid jobname_display; do
        echo "  Job ID: $jobid, Name: $jobname_display"
    done

    # Ask for confirmation
    echo
    read -p "Do you want to cancel these jobs? (y/N): " -r confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$pending_jobs" | while IFS=: read -r jobid jobname_display; do
            echo "Cancelling job $jobid ($jobname_display)..."
            scancel "$jobid"
        done
        echo "Jobs cancelled."
    else
        echo "Operation cancelled."
    fi
}