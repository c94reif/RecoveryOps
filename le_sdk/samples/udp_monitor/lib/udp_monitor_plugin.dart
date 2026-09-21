import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:le_sdk/le_sdk.dart';

/// Sample extension demonstrating the host-brokered UDP `NetworkService`.
///
/// A WebExtension cannot open raw/UDP/multicast sockets (browser sandbox).
/// `context.network` proxies socket work to the native host: this panel joins
/// a multicast group, streams incoming datagrams, and sends datagrams back —
/// none of which the WebView could do on its own.
class UdpMonitorPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'udp_monitor';

  @override
  String get name => 'UDP Monitor';

  @override
  String get description => 'Monitor and send UDP multicast/unicast datagrams';

  @override
  IconData get icon => Icons.lan;

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _UdpMonitorPanel(context: context);
}

/// One received (or sent) datagram, for the log.
class _LogEntry {
  final bool inbound;
  final String source; // "ip:port" for inbound, "→ group:port" for outbound
  final Uint8List bytes;
  final DateTime at;

  _LogEntry({
    required this.inbound,
    required this.source,
    required this.bytes,
    required this.at,
  });
}

class _UdpMonitorPanel extends StatefulWidget {
  final ExtensionContext context;
  const _UdpMonitorPanel({required this.context});

  @override
  State<_UdpMonitorPanel> createState() => _UdpMonitorPanelState();
}

/// Transport mode the panel operates in.
enum _Mode { multicast, unicast }

class _UdpMonitorPanelState extends State<_UdpMonitorPanel> {
  // Multicast defaults (see tools/udp_sender.py); the address field doubles as
  // the unicast destination IP when in unicast mode.
  final _addressController = TextEditingController(text: '239.1.2.3');
  final _portController = TextEditingController(text: '5005');
  final _sendController = TextEditingController(text: 'PING');
  final _scrollController = ScrollController();

  final _log = <_LogEntry>[];
  static const _maxLogEntries = 200;

  _Mode _mode = _Mode.multicast;
  UdpSubscription? _subscription;
  StreamSubscription<UdpDatagram>? _streamSub;
  bool _connecting = false;
  String? _status; // last status / error line

  bool get _connected => _subscription != null;
  bool get _isUnicast => _mode == _Mode.unicast;

  void _setMode(_Mode mode) {
    if (_mode == mode || _connected) return;
    setState(() {
      _mode = mode;
      // Swap the address field to a sensible default for the new mode.
      _addressController.text = mode == _Mode.multicast ? '239.1.2.3' : '';
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _subscription?.close();
    _addressController.dispose();
    _portController.dispose();
    _sendController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  void _appendLog(_LogEntry entry) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, entry);
      if (_log.length > _maxLogEntries) {
        _log.removeRange(_maxLogEntries, _log.length);
      }
    });
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    final port = int.tryParse(_portController.text.trim());
    if (port == null) {
      _setStatus('Enter a valid port.');
      return;
    }
    final group = _addressController.text.trim();
    if (_isUnicast == false && group.isEmpty) {
      _setStatus('Enter a multicast group.');
      return;
    }

    setState(() {
      _connecting = true;
      _status = _isUnicast
          ? 'Binding unicast :$port …'
          : 'Subscribing to $group:$port …';
    });

    try {
      // The await resolves only once the host socket is bound (+ joined, for
      // multicast). A failed bind (port in use, deny-listed) throws here.
      final sub = _isUnicast
          ? await widget.context.network.subscribeUnicast(port)
          : await widget.context.network.subscribeMulticast(group, port);
      _streamSub = sub.datagrams.listen(
        (dgram) => _appendLog(_LogEntry(
          inbound: true,
          source: '${dgram.sourceAddress}:${dgram.sourcePort}',
          bytes: dgram.bytes,
          at: dgram.receivedAt,
        )),
        onError: (Object e) => _setStatus('Stream error: $e'),
      );
      setState(() {
        _subscription = sub;
        _connecting = false;
        _status = _isUnicast
            ? 'Listening unicast on :$port'
            : 'Listening on $group:$port';
      });
    } catch (e) {
      setState(() {
        _connecting = false;
        _status = 'Subscribe failed: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await _streamSub?.cancel();
    _streamSub = null;
    await _subscription?.close();
    setState(() {
      _subscription = null;
      _status = 'Disconnected';
    });
  }

  Future<void> _send() async {
    final text = _sendController.text;
    if (text.isEmpty) return;
    final bytes = Uint8List.fromList(utf8.encode(text));
    final address = _addressController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (port == null) {
      _setStatus('Enter a valid port to send.');
      return;
    }
    if (_isUnicast && address.isEmpty) {
      _setStatus('Enter a destination IP to send.');
      return;
    }

    try {
      SendResult result;
      if (_subscription != null) {
        // Send from the bound socket — replies (if any) arrive on our stream.
        // For unicast the bound socket needs an explicit destination.
        result = _isUnicast
            ? await _subscription!.send(bytes, destinationIp: address, port: port)
            : await _subscription!.send(bytes);
      } else {
        // Fire-and-forget from an ephemeral socket (no subscription needed).
        result = _isUnicast
            ? await widget.context.network.sendUnicast(address, port, bytes)
            : await widget.context.network.sendMulticast(address, port, bytes);
      }
      if (result.success) {
        _appendLog(_LogEntry(
          inbound: false,
          source: '→ $address:$port',
          bytes: bytes,
          at: DateTime.now(),
        ));
        _setStatus('Sent ${bytes.length} bytes');
      } else {
        _setStatus('Send failed: ${result.error}');
      }
    } catch (e) {
      _setStatus('Send error: $e');
    }
  }

  void _clearLog() => setState(_log.clear);

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return Container(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(colors),
          _modeToggle(colors),
          _connectionBar(colors),
          if (_status != null) _statusLine(colors),
          Expanded(child: _logView(colors)),
          _sendBar(colors),
        ],
      ),
    );
  }

  Widget _header(LatticeColorScheme colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Icon(Icons.lan, size: 16, color: colors.accent),
            const SizedBox(width: 8),
            Text('UDP Monitor',
                style: TextStyle(
                    color: colors.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _connected ? colors.accent : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(_connected ? 'LIVE' : 'IDLE',
                style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
        ),
      );

  /// Segmented Multicast / Unicast selector. Disabled while connected.
  Widget _modeToggle(LatticeColorScheme colors) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(
          children: [
            _modeChip(colors, 'Multicast', _Mode.multicast),
            const SizedBox(width: 8),
            _modeChip(colors, 'Unicast', _Mode.unicast),
          ],
        ),
      );

  Widget _modeChip(LatticeColorScheme colors, String label, _Mode mode) {
    final selected = _mode == mode;
    return Expanded(
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: _connected ? null : () => _setMode(mode),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? colors.accent : colors.background,
            side: BorderSide(
                color: selected ? colors.accent : colors.borderActive),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.background : colors.textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectionBar(LatticeColorScheme colors) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _field(
                colors,
                _addressController,
                _isUnicast ? 'Destination IP' : 'Group',
                // In unicast mode the address is only the send destination, so
                // it stays editable even while listening.
                enabled: _isUnicast || !_connected,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _field(colors, _portController, 'Port',
                  enabled: !_connected,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _connecting
                    ? null
                    : (_connected ? _disconnect : _connect),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.background,
                  side: BorderSide(color: colors.borderActive),
                ),
                child: _connecting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: colors.accent),
                      )
                    : Text(_connected ? 'Stop' : 'Listen',
                        style: TextStyle(color: colors.accent)),
              ),
            ),
          ],
        ),
      );

  Widget _statusLine(LatticeColorScheme colors) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(_status!,
            style: TextStyle(color: colors.textSecondary, fontSize: 12)),
      );

  Widget _logView(LatticeColorScheme colors) {
    if (_log.isEmpty) {
      // Scrollable so the empty state never overflows when the panel is short
      // (e.g. the soft keyboard reduces the available height).
      return LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.satellite_alt,
                        size: 40, color: colors.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      _isUnicast
                          ? 'No datagrams yet.\nTap Listen to bind a unicast port.'
                          : 'No datagrams yet.\nTap Listen to join a multicast group.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _log.length,
      itemBuilder: (_, i) => _logTile(colors, _log[i]),
    );
  }

  Widget _logTile(LatticeColorScheme colors, _LogEntry e) {
    final ts = e.at.toIso8601String().substring(11, 23); // HH:mm:ss.mmm
    return ClipRect(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: e.inbound ? colors.accent : colors.textSecondary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  e.inbound ? Icons.south_west : Icons.north_east,
                  size: 12,
                  color: e.inbound ? colors.accent : colors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(e.source,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Text('$ts  ${e.bytes.length}B',
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(_hexDump(e.bytes),
                style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace')),
            const SizedBox(height: 2),
            Text(_asciiDump(e.bytes),
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _sendBar(LatticeColorScheme colors) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Clear log',
              onPressed: _log.isEmpty ? null : _clearLog,
              icon: Icon(Icons.delete_outline, color: colors.textSecondary),
            ),
            Expanded(
              child: _field(colors, _sendController, 'Payload to send'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.background,
                  side: BorderSide(color: colors.borderActive),
                ),
                child: Icon(Icons.send, color: colors.accent, size: 20),
              ),
            ),
          ],
        ),
      );

  Widget _field(
    LatticeColorScheme colors,
    TextEditingController controller,
    String hint, {
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(color: colors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.textSecondary),
          isDense: true,
          filled: true,
          fillColor: colors.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: colors.borderActive),
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: colors.borderActive),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: colors.accent),
          ),
        ),
      );

  // ---- byte rendering -------------------------------------------------------

  String _hexDump(Uint8List bytes) {
    final take = bytes.length > 32 ? bytes.sublist(0, 32) : bytes;
    final hex = take
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return bytes.length > 32 ? '$hex …' : hex;
  }

  String _asciiDump(Uint8List bytes) {
    final take = bytes.length > 64 ? bytes.sublist(0, 64) : bytes;
    final ascii = String.fromCharCodes(
        take.map((b) => (b >= 32 && b < 127) ? b : 0x2e)); // '.' for non-print
    return bytes.length > 64 ? '$ascii …' : ascii;
  }
}
