//
//  SecDescriptor.cpp
//  NativeTasks
//
//  Created by Paul Nettle on 5/25/19.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if defined(__linux__)

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <string.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <string>
#include <unistd.h>

#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/if_ether.h>

static std::string do_permaddr(const char *devname)
{
	// Constants
	constexpr const int kMaxAddrLen = 32;
	constexpr const int kGetPermAddr = 0x20;
	constexpr const int kSiocEthtool = 0x8946;
	constexpr const int kNetlinkGeneric = 16;

	// struct perm_addr - permanent hardware address
	// @cmd: Command number = kGetPermAddr
	// @size: On entry, the size of the buffer.  On return, the size of the address. The command fails if the buffer is too small.
	// @data: Buffer for the address
	//
	// Users must allocate the buffer immediately following this structure. A buffer size of kMaxAddrLen should be sufficient.
	struct perm_addr
	{
		__u32	cmd;
		__u32	size;
		__u8	data[0];
	};

	// Context for sub-commands
	struct cmd_context
	{
		const char *devname; // net device name
		int fd;              // socket suitable for ethtool ioctl
		struct ifreq ifr;    // ifreq suitable for ethtool ioctl
	};

	// Setup context
	struct cmd_context ctx;
	memset(&ctx, 0, sizeof(ctx));
	ctx.devname = devname;
	strcpy(ctx.ifr.ifr_name, ctx.devname);

	// Open control socket
	ctx.fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (ctx.fd < 0)
	{
		ctx.fd = socket(AF_NETLINK, SOCK_RAW, kNetlinkGeneric);
		if (ctx.fd < 0) return "Error: 38421";
	}

	// Setup ioctl request for permanent address
	struct perm_addr *epaddr = reinterpret_cast<struct perm_addr*>(malloc(sizeof(struct perm_addr) + kMaxAddrLen));
	if (!epaddr) return "Error: 38955";
	epaddr->cmd = kGetPermAddr;
	epaddr->size = kMaxAddrLen;

	// Get the permaddr
	ctx.ifr.ifr_data = reinterpret_cast<caddr_t>(epaddr);
	if (ioctl(ctx.fd, kSiocEthtool, &ctx.ifr) < 0) return "Error: 38719";
	if (close(ctx.fd) < 0) return "Error: 29854";

	// Convert it to a string
	std::string result;
	char msg[8];
	for (int i = 0; i < (int)epaddr->size; i++)
	{
		int byte = (int)epaddr->data[i];
		
		// Munge the bytes so it doesn't look like their address
		//byte = (byte + ((i+17)*57)) & 0xff;

		sprintf(msg, "%02x", byte);
		result += msg;
	}

	// Cleanup
	free(epaddr);
	return result;
}

/// Returns a string with the permanent ethernet MAC addresses
const char *secDescriptor(const char *name)
{
	static std::string result;
	result = do_permaddr(name);
	return result.c_str();
}

#endif // defined(__linux__)
