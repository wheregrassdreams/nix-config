# State declarations

This package currently preserves the repository's existing `my.data` contract
and host declarations. Its backup, synchronization, and export fragments are
reserved adapters; they do not implement recovery today.

The intended next model is for each capability to declare the state it owns,
with shared backup/recovery policy and execution. Importance, content type,
and available recovery source still need research before replacing this
contract or choosing tooling.
