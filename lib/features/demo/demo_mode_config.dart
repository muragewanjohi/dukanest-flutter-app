enum DemoSeedSize { small, medium, large }

DemoSeedSize get demoSeedSize {
  const raw = String.fromEnvironment('DEMO_SEED_SIZE', defaultValue: 'medium');
  switch (raw) {
    case 'small':
      return DemoSeedSize.small;
    case 'large':
      return DemoSeedSize.large;
    default:
      return DemoSeedSize.medium;
  }
}

int demoListLength(int baseLength) {
  final multiplier = switch (demoSeedSize) {
    DemoSeedSize.small => 1,
    DemoSeedSize.medium => 2,
    DemoSeedSize.large => 4,
  };
  return baseLength * multiplier;
}
