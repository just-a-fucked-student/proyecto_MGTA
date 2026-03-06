function [slots_cell, GroundDelay, AirDelay] = assign_slots(slots, Controlled, Exempt, ETA_hours, ARCID)
ETA_min = ETA_hours*60