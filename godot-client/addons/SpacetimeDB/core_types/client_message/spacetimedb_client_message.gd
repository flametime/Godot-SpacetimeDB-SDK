class_name SpacetimeDBClientMessage

# Client Message Variant Tags (ensure these match server/protocol)
const SUBSCRIBE         := 0x00
const UNSUBSCRIBE       := 0x01
const ONEOFF_QUERY      := 0x02
const CALL_REDUCER      := 0x03
const CALL_PROCEDURE    := 0x04
