/// Professional email validation and security utility.
/// Provides RFC 5322 syntax validation, disposable/temporary email detection,
/// and common domain typo corrections.
class EmailValidator {
  EmailValidator._();

  // Strict RFC-compliant email regex
  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z]{2,})+$",
  );

  // Common disposable / throwaway email domains
  static const Set<String> _disposableDomains = {
    '10minutemail.com',
    '10minutemail.net',
    'tempmail.com',
    'temp-mail.org',
    'temp-mail.io',
    'guerrillamail.com',
    'guerrillamail.net',
    'guerrillamail.org',
    'guerrillamailblock.com',
    'sharklasers.com',
    'grr.la',
    'mailinator.com',
    'yopmail.com',
    'yopmail.fr',
    'yopmail.net',
    'trashmail.com',
    'trashmail.net',
    'dispostable.com',
    'getairmail.com',
    'mohmal.com',
    'fakemailgenerator.com',
    'crazymailing.com',
    'tempail.com',
    'throwawaymail.com',
    'mintemail.com',
    'generator.email',
    'emailondeck.com',
    'mytemp.email',
    'inboxkitten.com',
    'burnermail.io',
    'dropmail.me',
    'nada.ltd',
    'armyspy.com',
    'cuvox.de',
    'dayrep.com',
    'fleckens.hu',
    'gustr.com',
    'jourrapide.com',
    'rhyta.com',
    'superrito.com',
    'teleworm.us',
    'einrot.com',
  };

  // Typo corrections for popular providers
  static const Map<String, String> _domainTypoMap = {
    'gmai.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gmil.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmaik.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'hotmial.com': 'hotmail.com',
    'hotmaill.com': 'hotmail.com',
    'hotmai.com': 'hotmail.com',
    'hotmali.com': 'hotmail.com',
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'yhaoo.com': 'yahoo.com',
    'yaho.fr': 'yahoo.fr',
    'outlok.com': 'outlook.com',
    'outloo.com': 'outlook.com',
    'outlock.com': 'outlook.com',
    'icloud.co': 'icloud.com',
    'icloud.cm': 'icloud.com',
    'iclou.com': 'icloud.com',
    'prton.me': 'proton.me',
    'protonmai.com': 'protonmail.com',
  };

  /// Validates an email address for registration.
  /// Returns null if the email is valid and legitimate.
  /// Returns a user-friendly error message if invalid, fake or disposable.
  static String? validate(String email) {
    final clean = email.trim().toLowerCase();

    if (clean.isEmpty) {
      return 'Veuillez saisir une adresse e-mail.';
    }

    if (clean.length > 254) {
      return 'L\'adresse e-mail est trop longue.';
    }

    if (clean.contains(' ')) {
      return 'L\'adresse e-mail ne doit pas contenir d\'espaces.';
    }

    if (!clean.contains('@')) {
      return 'L\'adresse e-mail doit comporter un "@" (ex: nom@domaine.com).';
    }

    final parts = clean.split('@');
    if (parts.length != 2) {
      return 'L\'adresse e-mail contient trop de symboles "@".';
    }

    final localPart = parts[0];
    final domainPart = parts[1];

    if (localPart.isEmpty) {
      return 'La partie avant le "@" ne peut pas être vide.';
    }

    if (localPart.startsWith('.') || localPart.endsWith('.') || localPart.contains('..')) {
      return 'L\'adresse e-mail contient des points consécutifs ou mal placés.';
    }

    if (domainPart.isEmpty || !domainPart.contains('.')) {
      return 'Le nom de domaine est incomplet (ex: exemple.com).';
    }

    if (!_emailRegExp.hasMatch(clean)) {
      return 'Format d\'adresse e-mail invalide. Veuillez vérifier votre saisie.';
    }

    // Check top-level domain (TLD)
    final tld = domainPart.split('.').last;
    if (tld.length < 2) {
      return 'L\'extension du domaine (ex: .com, .fr) est invalide.';
    }

    // Check against disposable / temporary email services
    if (_disposableDomains.contains(domainPart)) {
      return 'Les adresses e-mail jetables ou temporaires ne sont pas acceptées. Veuillez utiliser votre véritable e-mail.';
    }

    // Check for common typos
    if (_domainTypoMap.containsKey(domainPart)) {
      final suggestion = _domainTypoMap[domainPart];
      return 'Vouliez-vous dire $localPart@$suggestion ? Veuillez corriger votre e-mail.';
    }

    return null;
  }

  /// Normalizes an email address (trims and lowercases).
  static String normalize(String email) => email.trim().toLowerCase();
}
