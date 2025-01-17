// ignore_for_file: invalid_annotation_target

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';
part 'address.g.dart';

enum AddressType {
  receiveActive,
  receiveUnused,
  receiveUsed,
  changeActive,
  changeUsed,
  notMine,
}

@freezed
class Address with _$Address {
  factory Address({
    required String address,
    required int index,
    required AddressType type,
    String? label,
    String? sentTxId,
    bool? isReceive,
    @Default(false) bool saving,
    @Default('') String errSaving,
    @Default(false) bool unspendable,
    @Default(true) bool isMine,
    @Default(0) int highestPreviousBalance,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    List<bdk.LocalUtxo>? utxos,
  }) = _Address;
  const Address._();

  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);

  int calculateBalance() {
    return utxos?.fold(
          0,
          (amt, tx) => tx.isSpent ? amt : (amt ?? 0) + tx.txout.value,
        ) ??
        0;
  }

  List<bdk.OutPoint> getUnspentUtxosOutpoints() {
    return utxos?.where((tx) => !tx.isSpent).map((tx) => tx.outpoint).toList() ?? [];
  }

  bool hasSpentAndNoBalance() {
    return (utxos?.where((tx) => tx.isSpent).isNotEmpty ?? false) && calculateBalance() == 0;
  }

  bool hasInternal() {
    return utxos?.where((tx) => tx.keychain == bdk.KeychainKind.Internal).isNotEmpty ?? false;
  }

  bool hasExternal() {
    return utxos?.where((tx) => tx.keychain == bdk.KeychainKind.External).isNotEmpty ?? false;
  }

  bool hasReceive() {
    return utxos?.where((tx) => tx.keychain == bdk.KeychainKind.External).isNotEmpty ?? false;
  }

  AddressType getAddressType() {
    final isChange = hasInternal() || (isReceive != null && !isReceive!);
    if (calculateBalance() > 0) {
      if (isChange) return AddressType.changeActive;
      return AddressType.receiveActive;
    }

    if (highestPreviousBalance > 0) {
      if (isChange) return AddressType.changeUsed;
      return AddressType.receiveUsed;
    }
    if (!isMine) return AddressType.notMine;
    return AddressType.receiveUnused;
  }

  bool isReceiving() {
    final type = getAddressType();
    switch (type) {
      case AddressType.receiveActive:
      case AddressType.receiveUnused:
      case AddressType.receiveUsed:
        return true;
      default:
        return false;
    }
  }

  String miniString() {
    return address.substring(0, 6) + '...' + address.substring(address.length - 6);
  }

  String largeString() {
    return address.substring(0, 10) + '...' + address.substring(address.length - 10);
  }
}
