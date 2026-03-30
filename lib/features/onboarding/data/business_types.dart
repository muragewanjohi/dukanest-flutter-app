/// Store registration business types (labels match web onboarding).
class BusinessTypeOption {
  const BusinessTypeOption({
    required this.value,
    required this.description,
  });

  /// Value sent as `businessType` to the register API.
  final String value;
  final String description;
}

/// Ordered list aligned with product onboarding UI.
const List<BusinessTypeOption> kBusinessTypeOptions = [
  BusinessTypeOption(
    value: 'Fashion & Clothing',
    description: 'Clothes, shoes, handbags, accessories, tailoring.',
  ),
  BusinessTypeOption(
    value: 'Beauty & Personal Care',
    description: 'Cosmetics, skincare, hair products, barbershops, salons.',
  ),
  BusinessTypeOption(
    value: 'Electronics & Gadgets',
    description: 'Phones, laptops, accessories, earphones, smart devices.',
  ),
  BusinessTypeOption(
    value: 'Home & Kitchen',
    description: 'Furniture, utensils, decor, appliances.',
  ),
  BusinessTypeOption(
    value: 'Groceries & Food',
    description: 'Mini-marts, food stores, packaged foods.',
  ),
  BusinessTypeOption(
    value: 'Bakery & Cakes',
    description: 'Bakeries, cake shops, pastry businesses.',
  ),
  BusinessTypeOption(
    value: 'Restaurant & Takeaway',
    description: 'Food vendors, restaurants, fast food.',
  ),
  BusinessTypeOption(
    value: 'Agriculture & Farm Supplies',
    description: 'Seeds, fertilizers, agrovet products, farm tools.',
  ),
  BusinessTypeOption(
    value: 'Flowers & Gifts',
    description: 'Florists, gift shops, hampers, event gifts.',
  ),
  BusinessTypeOption(
    value: 'Health & Pharmacy',
    description: 'Pharmacies, supplements, medical supplies.',
  ),
  BusinessTypeOption(
    value: 'Automotive & Motorbike',
    description: 'Car parts, accessories, motorcycle gear.',
  ),
  BusinessTypeOption(
    value: 'Hardware & Construction',
    description: 'Tools, building materials, plumbing supplies.',
  ),
  BusinessTypeOption(
    value: 'Sports & Outdoor',
    description: 'Gym equipment, bicycles, sports gear.',
  ),
  BusinessTypeOption(
    value: 'Toys, Kids & Baby Products',
    description: 'Toys, baby clothes, baby products.',
  ),
  BusinessTypeOption(
    value: 'Pets & Animals',
    description: 'Pet food, accessories, ornamental fish, pet stores.',
  ),
  BusinessTypeOption(
    value: 'Other',
    description: 'Choose this if your business does not fit the categories above.',
  ),
];
