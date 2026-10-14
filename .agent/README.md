# Shared agent resources

This is the planned source location for resources shared by agent
applications, including skills and MCP definitions. Keep application runtime
state out of this directory; it is owned and backed up with the application
that creates it.

Resource deployment and application-specific discovery are not wired yet.
Add a resource only after its consumer and deployment behavior are clear.
