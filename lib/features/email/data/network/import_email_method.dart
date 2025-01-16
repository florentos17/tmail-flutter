import 'package:email_recovery/email_recovery/email_recovery_action.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/method/request/set_method.dart';
import 'package:jmap_dart_client/jmap/core/patch_object.dart';
import 'package:jmap_dart_client/jmap/core/request/request_invocation.dart';

class ImportEmailMethod extends SetMethodNoNeedAccountId<EmailRecoveryAction> with OptionalUpdateSingleton<PatchObject> {

  String blobId;
  String sentMailboxId;

  ImportEmailMethod(this.blobId, this.sentMailboxId);

  @override
  MethodName get methodName => MethodName('Email/import');

  @override
  Set<CapabilityIdentifier> get requiredCapabilities => {
    CapabilityIdentifier.jmapCore,
    CapabilityIdentifier.jmapMail,
  };

  @override
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    Map<String, Map<String, Object>> patches = {
      "importedEmail": {
        "blobId": blobId,
        "mailboxIds": {sentMailboxId: true},
        "keywords": {"\$seen": true},
      }
    };

    writeNotNull('emails', patches);
    return val;
  }

  @override
  List<Object?> get props => [create, update, destroy];
}