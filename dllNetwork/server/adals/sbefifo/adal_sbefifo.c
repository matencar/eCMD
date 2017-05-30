//IBM_PROLOG_BEGIN_TAG
/* 
 * Copyright 2003,2017 IBM International Business Machines Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * 	http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
//IBM_PROLOG_END_TAG

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <poll.h>
#include <stdio.h>
#include <arpa/inet.h>
#include "adal_sbefifo.h"


adal_t * adal_sbefifo_open(const char * device, int flags) {
	adal_t * adal = NULL;

	adal = (adal_t *)malloc(sizeof(*adal));
	if (adal == NULL) {
		return NULL;
	}

	adal->fd = open(device, flags);
	if (adal->fd == -1) {
		free(adal);
		adal = NULL;
	}

	return adal;
}

ssize_t adal_sbefifo_submit(adal_t * adal, adal_sbefifo_request * request,
		adal_sbefifo_reply * reply, unsigned long timeout_in_msec) {

	int rc = -1;

	struct pollfd pollfd;
	int ret = 0;

	pollfd.fd = adal->fd;
	pollfd.events = POLLOUT | POLLERR;

	if((ret = poll(&pollfd, 1, timeout_in_msec)) < 0) {
		perror("Waiting for fifo device failed");
		return -1;
	}

	if (pollfd.revents & POLLERR) {

		return -1;
	}

	uint8_t * buf = (uint8_t *) request->data;
	int size_bytes = request->wordcount << 2;
        if ( adal_is_byte_swap_needed() ) {
                uint32_t *tmpBuf = (uint32_t *) request->data;
                for ( uint32_t idx = 0; idx < request->wordcount; idx++ ){
                        tmpBuf[idx] = htonl(tmpBuf[idx]);
                }
        }
	ret = write(adal->fd, buf, size_bytes);
	if (ret < 0) {
		perror("Writing user input failed");
		return -1;
	} else if (ret != size_bytes) {
		fprintf(stderr, "Incorrect number of bytes written %d != %d\n", ret, size_bytes);
		return -1;
	}

	pollfd.fd = adal->fd;
	pollfd.events = POLLIN | POLLERR;

	if((ret = poll(&pollfd, 1, timeout_in_msec) < 0)) {
		perror("Waiting for fifo device failed");
		return -1;
	}

	if (pollfd.revents & POLLERR) {
		fprintf(stderr, "POLLERR while waiting for readable fifo\n");
		return -1;
	}

	buf = (uint8_t *) reply->data;
	int ret_bytes = 0;
	size_bytes = reply->wordcount << 2;
	while (size_bytes > 0) {
		if((ret = read(adal->fd, buf + ret_bytes, size_bytes)) < 0) {
			if (errno == EAGAIN)
				break;
			perror("Reading fifo device failed");
			return -1;
		}
		ret_bytes += ret;
		size_bytes -= ret;
	}


	reply->wordcount = ret_bytes >> 2;

        if ( adal_is_byte_swap_needed() ) {
                uint32_t *tmpBuf = (uint32_t *) reply->data;
                for ( uint32_t idx = 0; idx < reply->wordcount; idx++ ){
                        tmpBuf[idx] = ntohl(tmpBuf[idx]);
                }
        }

	rc = ret_bytes;

	return rc;

}

int adal_sbefifo_close(adal_t * adal) {
	int rc = 0;

	if (!adal)
		return 0;

	rc = close(adal->fd);

	free(adal);
	adal = NULL;

	return rc;
}

int adal_sbefifo_request_reset(adal_t * adal) {

	return 0;
}


ssize_t adal_sbefifo_ffdc_extract(adal_t * adal, int scope, void ** buf) {
  *buf=NULL;
  return 0;
}

int adal_sbefifo_unlock(adal_t * adal, int scope) {

	return 0;

}

