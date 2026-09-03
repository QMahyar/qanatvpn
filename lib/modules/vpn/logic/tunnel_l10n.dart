import '../../../core/services/tunnel.dart';
import '../../../l10n/app_localizations.dart';

/// UI strings for tunnel states and block reasons. Keeps raw enum names out
/// of the screens and lets FA users read actual Persian.
extension TunnelStateL10n on TunnelState {
  String label(AppLocalizations l10n) => switch (this) {
    TunnelState.connected => l10n.stateConnected,
    TunnelState.connecting => l10n.stateConnecting,
    TunnelState.disconnecting => l10n.stateDisconnecting,
    TunnelState.blocked => l10n.stateBlocked,
    TunnelState.reconnecting => l10n.stateReconnecting,
    TunnelState.disconnected => l10n.stateTapToConnect,
  };
}

extension TunnelBlockReasonL10n on TunnelBlockReason {
  String label(AppLocalizations l10n) => switch (this) {
    TunnelBlockReason.vpnPermissionDenied => l10n.blockVpnPermissionDenied,
    TunnelBlockReason.establishFailed => l10n.blockEstablishFailed,
    TunnelBlockReason.airplaneMode => l10n.blockAirplaneMode,
    TunnelBlockReason.torDown => l10n.blockTorDown,
    TunnelBlockReason.boxStartFailed => l10n.blockBoxStartFailed,
    TunnelBlockReason.boxCrashed => l10n.blockBoxCrashed,
  };
}
