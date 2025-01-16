import 'package:collection/collection.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:core/utils/mail/mail_address.dart';
import 'package:get/get_utils/src/get_utils/get_utils.dart';
import 'package:html/parser.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:model/extensions/email_extension.dart';
import 'package:tmail_ui_user/features/email/domain/state/download_attachment_for_web_state.dart';
import 'package:tmail_ui_user/features/email/presentation/model/email_unsubscribe.dart';
import 'package:tmail_ui_user/features/thread/domain/constants/thread_constants.dart';
import 'package:tmail_ui_user/main/error/capability_validator.dart';

import '../../../composer/domain/model/email_request.dart';

class EmailUtils {

  static Properties getPropertiesForEmailGetMethod(Session session, AccountId accountId) {
    if (CapabilityIdentifier.jamesCalendarEvent.isSupported(session, accountId)) {
      return ThreadConstants.propertiesCalendarEvent;
    } else {
      return ThreadConstants.propertiesDefault;
    }
  }

  static EmailUnsubscribe? parsingUnsubscribe(String listUnsubscribe) {
    if (listUnsubscribe.isEmpty) {
      return null;
    }

    final regExpMailtoLinks = RegExp(r'mailto:([^>,]*)');
    final allMatchesMailtoLinks = regExpMailtoLinks.allMatches(listUnsubscribe);
    final listMailtoLinks = allMatchesMailtoLinks
      .map((match) => match.group(0))
      .whereNotNull()
      .toList();
    log('EmailUtils::parsingUnsubscribe:listMailtoLinks: $listMailtoLinks');

    final regExpHttpLinks = RegExp(r'http([^>,]*)');
    final allMatchesHttpLinks = regExpHttpLinks.allMatches(listUnsubscribe);
    final listHttpLinks = allMatchesHttpLinks
      .map((match) => match.group(0))
      .whereNotNull()
      .toList();
    log('EmailUtils::parsingUnsubscribe:listHttpLinks: $listHttpLinks');

    if (listMailtoLinks.isNotEmpty || listHttpLinks.isNotEmpty) {
      return EmailUnsubscribe(
        httpLinks: listHttpLinks,
        mailtoLinks: listMailtoLinks
      );
    } else {
      return null;
    }
  }

  static bool checkingIfAttachmentActionIsEnabled(Either<Failure, Success>? state) {
    return state?.fold(
      (failure) {
        return failure is DownloadAttachmentForWebFailure;
      },
      (success) {
        return success is DownloadAttachmentForWebSuccess
          || success is IdleDownloadAttachmentForWeb;
      }) ?? false;
  }

  static bool isSameDomain({
    required String emailAddress,
    required String internalDomain
  }) {
    log('EmailUtils::isSameDomain: emailAddress = $emailAddress | internalDomain = $internalDomain');
    return EmailUtils.isEmailAddressValid(emailAddress) &&
      emailAddress.split('@').last.toLowerCase() == internalDomain.toLowerCase();
  }

  static bool isEmailAddressValid(String address) {
    try {
      MailAddress mailAddress = MailAddress.validateAddress(address);
      return GetUtils.isEmail(mailAddress.stripDetails().asString()) && mailAddress.asString().isNotEmpty;
    } catch(e) {
      logError('EmailUtils::isEmailAddressValid: Exception = $e');
      return false;
    }
  }

  static Future<mailer.Message> createMessage(EmailRequest emailRequest, String currentUserEmail) async {
    final recipientsList = emailRequest.email
        .getRecipientEmailAddressList()
        .map((email) => mailer.Address(email))
        .toList();

    final htmlPartId = emailRequest.email.htmlBody?.first?.partId;
    final htmlContent = htmlPartId != null ? (emailRequest.email.bodyValues?[htmlPartId]?.value) : null;
    final textContent = parse(htmlContent).body?.text ?? '';

    return mailer.Message()
      ..from = mailer.Address(currentUserEmail, '')
      ..recipients.addAll(recipientsList)
      ..subject = emailRequest.email.subject ?? 'No Subject'
      ..text = textContent
      ..html = htmlContent;
  }

  static String MessageAsString(mailer.Message message) {
    final buffer = StringBuffer();

    void writeWithCRLF(String line) {
      buffer.write(line.replaceAll('\n', '\r\n'));
      if (!line.endsWith('\r\n')) {
        buffer.write('\r\n');
      }
    }

    if (message.from != null) {
      writeWithCRLF('From: ${message.from}');
    }

    final recipientAddresses = message.recipients.join(', ');
    if (recipientAddresses.isNotEmpty) {
      writeWithCRLF('To: $recipientAddresses');
    }

    final ccAddresses = message.ccRecipients.join(', ');
    if (ccAddresses.isNotEmpty) {
      writeWithCRLF('Cc: $ccAddresses');
    }

    final bccAddresses = message.bccRecipients.join(', ');
    if (bccAddresses.isNotEmpty) {
      writeWithCRLF('Bcc: $bccAddresses');
    }

    if (message.subject != null) {
      writeWithCRLF('Subject: ${message.subject}');
    }

    writeWithCRLF('Date: ${DateTime.now().toUtc().toIso8601String()}');

    if (message.html != null) {
      writeWithCRLF('Content-Type: text/html; charset="utf-8"');
    } else if (message.text != null) {
      writeWithCRLF('Content-Type: text/plain; charset="utf-8"');
    } else {
      writeWithCRLF('Content-Type: application/octet-stream');
    }

    // Add a blank line between headers and body
    buffer.write('\r\n');

    // Add email body
    if (message.text != null) {
      writeWithCRLF(message.text!);
    } else if (message.html != null) {
      writeWithCRLF(message.html!);
    }

    // Add attachments

    return buffer.toString();
  }
}