// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

/// The complete C API from the pinned liblsl headers.
///
/// Native calls are synchronous. A timeout can block the calling isolate.
/// Use the C header contracts for buffer sizes, return values, and ownership.
///
/// Release owned descriptions, inlets, and outlets with their matching destroy functions.
/// [lsl_get_xml] and string pulls allocate strings; release them with [lsl_destroy_string].
/// Name getters and [lsl_library_info] return borrowed strings. Do not free them.
/// XML element handles borrow their parent description. Keep that description alive.
/// Do not share an inlet handle between isolates.
///
/// See the [C headers](https://github.com/sccn/liblsl/blob/v1.17.7/include/lsl_c.h)
/// for the native API contracts.
library;

export 'src/third_party/liblsl.g.dart';
