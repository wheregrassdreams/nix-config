-- Managed by nix-config: modules/home/terminal/rex/init.lua
-- Rex: tmux-like keybindings
-- Prefix: Ctrl+A

-- Tabs
rex.bind("ctrl+a>n", "client.tab.new")
-- rex.bind("ctrl+a>n", "client.tab.next")
-- rex.bind("ctrl+a>p", "client.tab.previous")

-- Split panes
rex.bind("ctrl+a>shift+\\", "pane.split", {
  direction = "right",
})
rex.bind("ctrl+a>\\", "pane.split", {
  direction = "down",
})

-- Vim-style pane navigation
rex.bind("ctrl+a>h", "pane.focus", {
  direction = "left",
})
rex.bind("ctrl+a>j", "pane.focus", {
  direction = "down",
})
rex.bind("ctrl+a>k", "pane.focus", {
  direction = "up",
})
rex.bind("ctrl+a>l", "pane.focus", {
  direction = "right",
})

-- Zoom and close
rex.bind("ctrl+a>enter", "pane.zoom")
rex.bind("ctrl+a>x", "pane.close")

-- Sessions
rex.bind("ctrl+a>s", "session.switch")

-- Send Ctrl+A to the terminal
rex.bind("ctrl+a>ctrl+a", "pane.send_key", {
  key = "ctrl+a",
})

-- Resize mode
rex.bind("ctrl+a>r", "client.mode.enter", {
  name = "resize",
})

rex.bind("resize/h", "pane.resize", {
  direction = "left",
  amount = 5,
})
rex.bind("resize/j", "pane.resize", {
  direction = "down",
  amount = 5,
})
rex.bind("resize/k", "pane.resize", {
  direction = "up",
  amount = 5,
})
rex.bind("resize/l", "pane.resize", {
  direction = "right",
  amount = 5,
})

-- Escape exits resize mode
rex.bind("resize/enter", "client.mode.exit")
