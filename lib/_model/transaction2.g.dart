// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Transaction2 _$$_Transaction2FromJson(Map<String, dynamic> json) =>
    _$_Transaction2(
      txid: json['txid'] as String,
      received: json['received'] as int?,
      sent: json['sent'] as int?,
      fee: json['fee'] as int?,
      height: json['height'] as int?,
      timestamp: json['timestamp'] as int?,
      label: json['label'] as String?,
      fromAddress: json['fromAddress'] as String?,
      toAddress: json['toAddress'] as String?,
      psbt: json['psbt'] as String?,
      rbfEnabled: json['rbfEnabled'] as bool?,
      oldTx: json['oldTx'] as bool? ?? false,
      broadcastTime: json['broadcastTime'] as int?,
      vins: (json['vins'] as List<dynamic>?)?.map((e) => e as String).toList(),
      vouts:
          (json['vouts'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$_Transaction2ToJson(_$_Transaction2 instance) =>
    <String, dynamic>{
      'txid': instance.txid,
      'received': instance.received,
      'sent': instance.sent,
      'fee': instance.fee,
      'height': instance.height,
      'timestamp': instance.timestamp,
      'label': instance.label,
      'fromAddress': instance.fromAddress,
      'toAddress': instance.toAddress,
      'psbt': instance.psbt,
      'rbfEnabled': instance.rbfEnabled,
      'oldTx': instance.oldTx,
      'broadcastTime': instance.broadcastTime,
      'vins': instance.vins,
      'vouts': instance.vouts,
    };
