`seq_greater` - the formula from the header, verbatim.
`on_receive`: first packet - just remember it. If `seq` is newer than `remote_ack`: shift = seq - remote_ack;
the old bits shift left by shift, and the old ack becomes bit (shift - 1); for shift > 32 the bits are cleared
(careful: shifting a uint by 32 or more is an error). If the packet is older: back = remote_ack - seq, and for 1 <= back <= 32
set bit (back - 1).
`process_acks`: `ack_one(ack)`, then for each i in 0..31 whose bit is set - `ack_one(ack - (ushort)(i + 1))`.
