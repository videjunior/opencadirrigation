/// Validation of JSON values against the part of JSON Schema 2020-12 the
/// tools of the MCP server (mcp_server.dart, oci_mcp_tools.dart) are written
/// in: `type`, `enum`, `const`, `properties`, `required`,
/// `additionalProperties`, `items`, `minItems`, `maxItems`, `minLength`,
/// `maxLength`, `pattern`, `minimum`, `maximum`, `exclusiveMinimum` and
/// `exclusiveMaximum`; the annotations (`title`, `description`, `default`,
/// `examples`, `$schema`) are read past. [schemaProblems] refuses a schema
/// with any other keyword, so that no tool can be validated less strictly
/// than its schema says (the MCP specification asks that a schema which
/// cannot be fully validated be rejected rather than treated as
/// permissive). No `$ref` is ever followed, local or remote.
///
/// Pure Dart: on the web an integer may arrive as a double, so `integer`
/// is a number without a fractional part, as JSON Schema defines it.
library;

/// The keywords [schemaErrors] validates.
const schemaAssertions = {
  'type',
  'enum',
  'const',
  'properties',
  'required',
  'additionalProperties',
  'items',
  'minItems',
  'maxItems',
  'minLength',
  'maxLength',
  'pattern',
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
};

/// The keywords that only describe ([schemaErrors] reads past them).
const schemaAnnotations = {r'$schema', 'title', 'description', 'default', 'examples'};

const _types = {'string', 'number', 'integer', 'boolean', 'object', 'array', 'null'};

/// The deepest schema [schemaProblems] accepts (a bound against a schema
/// built to make the validator work too hard).
const maxSchemaDepth = 12;

/// What is wrong with [schema] as a schema of this subset: unknown keywords,
/// a `required` key without a property, a type that does not exist… (empty
/// when it is fine). [at] names the place in the messages.
List<String> schemaProblems(Object? schema, {String at = 'schema', int depth = 0}) {
  final out = <String>[];
  if (schema is bool) return out;
  if (schema is! Map) return ['$at: a schema is an object or a boolean'];
  if (depth > maxSchemaDepth) return ['$at: deeper than $maxSchemaDepth levels'];
  for (final k in schema.keys) {
    if (!schemaAssertions.contains(k) && !schemaAnnotations.contains(k)) out.add('$at: keyword "$k" is not supported');
  }
  final type = schema['type'];
  if (type != null) {
    final names = type is List ? type : [type];
    if (names.isEmpty || names.any((t) => t is! String || !_types.contains(t))) out.add('$at: type must be one of ${_types.join(', ')} (or a list of them)');
  }
  final enumValues = schema['enum'];
  if (enumValues != null && (enumValues is! List || enumValues.isEmpty)) out.add('$at: enum must be a list with at least one value');
  final props = schema['properties'];
  if (props != null) {
    if (props is! Map) {
      out.add('$at: properties must be an object');
    } else {
      for (final e in props.entries) {
        out.addAll(schemaProblems(e.value, at: '$at.properties.${e.key}', depth: depth + 1));
      }
    }
  }
  final required = schema['required'];
  if (required != null) {
    if (required is! List || required.any((r) => r is! String)) {
      out.add('$at: required must be a list of names');
    } else {
      for (final r in required) {
        if (props is! Map || !props.containsKey(r)) out.add('$at: "$r" is required but has no property');
      }
    }
  }
  final extra = schema['additionalProperties'];
  if (extra != null) out.addAll(schemaProblems(extra, at: '$at.additionalProperties', depth: depth + 1));
  final items = schema['items'];
  if (items != null) out.addAll(schemaProblems(items, at: '$at.items', depth: depth + 1));
  for (final k in const ['minItems', 'maxItems', 'minLength', 'maxLength']) {
    final v = schema[k];
    if (v != null && (v is! num || v < 0 || v != v.roundToDouble())) out.add('$at: $k must be a whole number of 0 or more');
  }
  for (final k in const ['minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum']) {
    final v = schema[k];
    if (v != null && (v is! num || !v.isFinite)) out.add('$at: $k must be a number');
  }
  final pattern = schema['pattern'];
  if (pattern != null) {
    if (pattern is! String) {
      out.add('$at: pattern must be a string');
    } else {
      try {
        RegExp(pattern, unicode: true);
      } on FormatException {
        out.add('$at: pattern is not a regular expression');
      }
    }
  }
  return out;
}

/// The ways [value] breaks [schema], one sentence each that names the place
/// ([path], e.g. `arguments.format`), at most [max] of them; empty when the
/// value is valid.
List<String> schemaErrors(Object? value, Object? schema, {String path = 'arguments', int max = 20}) {
  final out = <String>[];
  _check(value, schema, path, out, max);
  return out;
}

String _show(Object? v) {
  final s = v is String ? '"$v"' : '$v';
  return s.length > 60 ? '${s.substring(0, 57)}…' : s;
}

String _typeOf(Object? v) => switch (v) {
  null => 'null',
  bool _ => 'boolean',
  num n => n.isFinite && n == n.roundToDouble() ? 'integer' : 'number',
  String _ => 'string',
  List _ => 'array',
  Map _ => 'object',
  _ => 'unknown',
};

bool _hasType(Object? v, String t) => switch (t) {
  'null' => v == null,
  'boolean' => v is bool,
  'integer' => v is num && v.isFinite && v == v.roundToDouble(),
  'number' => v is num && v.isFinite,
  'string' => v is String,
  'array' => v is List,
  'object' => v is Map,
  _ => false,
};

bool _equal(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_equal(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_equal(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}

void _check(Object? v, Object? schema, String path, List<String> out, int max) {
  if (out.length >= max) return;
  if (schema == true || schema == null) return;
  if (schema == false) {
    out.add('$path: not allowed');
    return;
  }
  if (schema is! Map) return;
  final type = schema['type'];
  if (type != null) {
    final names = [
      for (final t in type is List ? type : [type]) '$t',
    ];
    if (!names.any((t) => _hasType(v, t))) {
      out.add('$path: must be ${names.map((t) => t == 'integer' ? 'a whole number' : (t == 'array' || t == 'object' ? 'an $t' : 'a $t')).join(' or ')} (got ${_typeOf(v)} ${_show(v)})');
      return;
    }
  }
  final enumValues = schema['enum'];
  if (enumValues is List && !enumValues.any((e) => _equal(e, v))) {
    out.add('$path: must be one of ${enumValues.map((e) => e is String ? e : '$e').join(', ')} (got ${_show(v)})');
    return;
  }
  if (schema.containsKey('const') && !_equal(schema['const'], v)) {
    out.add('$path: must be ${_show(schema['const'])} (got ${_show(v)})');
    return;
  }
  if (v is String) {
    final minL = schema['minLength'], maxL = schema['maxLength'];
    final length = v.runes.length;
    if (minL is num && length < minL) out.add(minL == 1 ? '$path: must not be empty' : '$path: must have at least $minL characters');
    if (maxL is num && length > maxL) out.add('$path: must have at most $maxL characters (it has $length)');
    final pattern = schema['pattern'];
    if (pattern is String && !RegExp(pattern, unicode: true).hasMatch(v)) {
      final what = schema['description'];
      out.add('$path: ${_show(v)} is not valid${what is String && what.length < 140 ? ' ($what)' : ''}');
    }
  }
  if (v is num) {
    final min = schema['minimum'], maxV = schema['maximum'], xmin = schema['exclusiveMinimum'], xmax = schema['exclusiveMaximum'];
    if (min is num && v < min) out.add('$path: must be at least $min (got $v)');
    if (maxV is num && v > maxV) out.add('$path: must be at most $maxV (got $v)');
    if (xmin is num && v <= xmin) out.add('$path: must be more than $xmin (got $v)');
    if (xmax is num && v >= xmax) out.add('$path: must be less than $xmax (got $v)');
  }
  if (v is List) {
    final minI = schema['minItems'], maxI = schema['maxItems'];
    if (minI is num && v.length < minI) out.add(minI == 1 ? '$path: must not be empty' : '$path: must have at least $minI items');
    if (maxI is num && v.length > maxI) out.add('$path: must have at most $maxI items (it has ${v.length})');
    final items = schema['items'];
    if (items != null) {
      for (var i = 0; i < v.length && out.length < max; i++) {
        _check(v[i], items, '$path[$i]', out, max);
      }
    }
  }
  if (v is Map) {
    final props = schema['properties'];
    final known = props is Map ? props : const {};
    final required = schema['required'];
    if (required is List) {
      for (final r in required) {
        if (!v.containsKey(r)) out.add('$path.$r: required');
      }
    }
    final extra = schema['additionalProperties'];
    for (final e in v.entries) {
      if (out.length >= max) return;
      final key = '${e.key}';
      if (known.containsKey(key)) {
        _check(e.value, known[key], '$path.$key', out, max);
      } else if (extra == false) {
        final names = known.keys.join(', ');
        out.add('$path: unknown argument "$key"${names.isEmpty ? ' (none is taken)' : ' (the ones taken are $names)'}');
      } else if (extra != null) {
        _check(e.value, extra, '$path.$key', out, max);
      }
    }
  }
}
