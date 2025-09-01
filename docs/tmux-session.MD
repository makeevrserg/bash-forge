# Start a new session
tmux new -s <session>

# Run script inside session
bash ./script.sh

# Press CTRL+B then CTRL+D to detach from session
# Type exit to close session

# Attach to session
tmux attach -t <session>

# See tmux sessions
tmux ls