#!/usr/bin/env python

# Wake-On-LAN 
# 
# Copyright (C) 2002 by Micro Systems Marc Balmer 
# Written by Marc Balmer, marc@msys.ch, http://www.msys.ch/ 
# This code is free software under the GPL

import struct, socket, sys 

def WakeOnLan(ethernet_address): 

# Construct a six-byte hardware address 

	addr_byte = ethernet_address.split(':') 
	hw_addr = struct.pack('BBBBBB', int(addr_byte[0], 16), 
	int(addr_byte[1], 16), 
	int(addr_byte[2], 16), 
	int(addr_byte[3], 16), 
	int(addr_byte[4], 16), 
	int(addr_byte[5], 16)) 

# Build the Wake-On-LAN "Magic Packet"... 

	msg = '\xff' * 6 + hw_addr * 16 

# ...and send it to the broadcast address using UDP 

	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) 
	s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1) 
	s.sendto(msg, ('<broadcast>', 9)) 
	s.close() 



try:

        wakeme = sys.argv[1]

except IndexError:
        print ""
        print "ERROR! : No hardware ethernet address provided"
        print "         Please Provide the Hardware Ehternet Address"
        print "         as the fist argument."
        print ""
        print "         eg . python wake.py 00:03:93:B0:A0:BA"
        print ""

else:
	WakeOnLan(wakeme)
