// License: Apache 2.0. See LICENSE file in root directory.
// Copyright(c) 2015 Intel Corporation. All Rights Reserved.

#include "context-libusb.h"
#include "../types.h"

namespace librealsense
{
    namespace platform
    {
        // EnsioVision - singleton access to usb_context to prevent multiple instances
        // Previously, different threads would create and destroy usb_context
        // Constantly calling libusb_init and libusb_exit starts and stops a scanner thread
        // in libusb, and libusb api does not appear to be thread safe

        std::recursive_mutex usb_context::g_mutex;
        int usb_context::g_count = 0;
        std::shared_ptr<usb_context> usb_context::_sp_usb_context;

        std::shared_ptr<usb_context> usb_context::get_usb_context()
        {
            std::lock_guard auto_lock(g_mutex);
            if (not _sp_usb_context)
                _sp_usb_context = std::shared_ptr<usb_context>(new usb_context());
            else
                _sp_usb_context->scan();

            return _sp_usb_context;
        }

        usb_context::usb_context() : _ctx(nullptr), _list(nullptr), _count(0)
        {
            std::lock_guard auto_lock(g_mutex);
            g_count++;
            if (g_count > 1)
            {
                g_count = g_count;
            }

            auto sts = libusb_init(&_ctx);
            if(sts != LIBUSB_SUCCESS)
            {
                LOG_ERROR("libusb_init failed");
            }
            _count = libusb_get_device_list(_ctx, &_list);
        }

        usb_context::~usb_context()
        {
            std::lock_guard auto_lock(g_mutex);
            g_count--;

            libusb_free_device_list(_list, true);
            assert(_handler_requests == 0); // we need the last libusb_close to trigger an event to stop the event thread
            if (_event_handler.joinable())
                _event_handler.join();
            libusb_exit(_ctx);
        }

        libusb_context* usb_context::get()
        {
            return _ctx;
        }

        void usb_context::start_event_handler()
        {
            std::lock_guard auto_lock(_mutex);
            if (!_handler_requests) 
            {
                // see "Applications which do not use hotplug support" in libusb's io.c
                if (_event_handler.joinable()) 
                {
                    _event_handler.join();
                    _kill_handler_thread = 0;
                }

                auto event_thread_fn = [this]() 
                {
                    while (!_kill_handler_thread)
                        libusb_handle_events_completed(_ctx, &_kill_handler_thread);
                };
                _event_handler = std::thread(event_thread_fn);
            }
            _handler_requests++;
        }

        void usb_context::stop_event_handler()
        {
            std::lock_guard auto_lock(_mutex);
            _handler_requests--;
            if (!_handler_requests)
            {
                // the last libusb_close will trigger and event and the handler thread will notice this is set
                _kill_handler_thread = 1;
            }
        }

        libusb_device* usb_context::get_device(uint8_t index)
        {
            return index < _count ? _list[index] : NULL;
        }

        size_t usb_context::scan()
        {
            std::lock_guard auto_lock(g_mutex);

            if (_list != nullptr)
                libusb_free_device_list(_list, true);

            _count = libusb_get_device_list(_ctx, &_list);
            return _count;
        }

        size_t usb_context::device_count()
        {
            return _count;
        }
    }
}
