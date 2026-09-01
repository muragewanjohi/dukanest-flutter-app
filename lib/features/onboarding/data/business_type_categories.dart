/// Curated category taxonomy — one flat list of real category names per
/// business type. Ported from storeflow's
/// `src/lib/categories/business-type-taxonomy.ts` (kept in sync by hand —
/// same list, same reasoning). See that file's header comment for the full
/// history: registration-time category selection replaced an earlier
/// auto-generate-everything design after the user pointed out that e.g.
/// "Aquarium & Fish Supplies" and "Pet Carriers & Housing" are very
/// different niches within "Pets & Animals" — a merchant who only does one
/// of them shouldn't get both created for them.
///
/// "Other" has no entry here on purpose — the register screen falls back
/// to a free-text "What are you selling?" field for that case, same as web.
const Map<String, List<String>> kBusinessTypeCategories = {
  'Fashion & Clothing': [
    "Women's Wear",
    "Men's Wear",
    "Kids' Wear",
    'Shoes',
    'Bags & Handbags',
    'Jewelry & Watches',
    'Belts & Wallets',
    'Sunglasses',
    'Traditional Wear',
    'Activewear',
    'Tailoring Services',
  ],
  'Beauty & Personal Care': [
    'Skincare',
    'Haircare',
    'Makeup & Cosmetics',
    'Fragrances & Perfumes',
    'Hair Extensions & Wigs',
    'Nail Care',
    'Bath & Body',
    "Men's Grooming",
    'Salon Services',
    'Barbershop Services',
    'Spa & Massage Services',
  ],
  'Electronics & Gadgets': [
    'Smartphones',
    'Laptops & Computers',
    'Phone Accessories',
    'Audio & Headphones',
    'Smart Watches & Wearables',
    'TVs & Home Entertainment',
    'Cameras & Photography',
    'Gaming',
    'Chargers & Power Banks',
    'Repair & Installation Services',
  ],
  'Home & Kitchen': [
    'Kitchen Appliances',
    'Cookware & Bakeware',
    'Home Decor',
    'Bedding & Bath',
    'Furniture',
    'Storage & Organization',
    'Cleaning Supplies',
    'Lighting',
    'Dining & Serving',
  ],
  'Groceries & Food': [
    'Fresh Produce',
    'Packaged Foods',
    'Beverages',
    'Dairy & Eggs',
    'Grains & Cereals',
    'Snacks & Confectionery',
    'Cooking Oils & Fats',
    'Spices & Seasonings',
    'Household Essentials',
  ],
  'Bakery & Cakes': [
    'Celebration Cakes',
    'Cupcakes',
    'Bread & Pastries',
    'Cookies & Biscuits',
    'Custom Cake Orders',
    'Wedding Cakes',
    'Baking Ingredients & Supplies',
  ],
  'Restaurant & Takeaway': [
    'Main Dishes',
    'Fast Food',
    'Drinks & Beverages',
    'Combo Meals',
    'Snacks',
    'Desserts',
    'Catering Services',
  ],
  'Agriculture & Farm Supplies': [
    'Seeds & Seedlings',
    'Fertilizers',
    'Agrochemicals & Pesticides',
    'Farm Tools & Equipment',
    'Animal Feeds',
    'Irrigation Supplies',
    'Veterinary Supplies',
  ],
  'Flowers & Gifts': [
    'Bouquets & Arrangements',
    'Gift Hampers',
    'Wedding Flowers',
    'Event Decor',
    'Gift Cards & Vouchers',
    'Balloons & Party Supplies',
    'Potted Plants',
    'Event Planning Services',
  ],
  'Health & Pharmacy': [
    'Prescription Medicine',
    'Over-the-Counter Medicine',
    'Vitamins & Supplements',
    'Medical Supplies & Equipment',
    'First Aid',
    'Baby Health',
    'Personal Protective Equipment',
  ],
  'Automotive & Motorbike': [
    'Car Parts & Accessories',
    'Motorcycle Parts & Gear',
    'Tyres & Rims',
    'Car Care & Detailing',
    'Helmets & Riding Gear',
    'Vehicle Electronics',
    'Repair & Mechanic Services',
  ],
  'Hardware & Construction': [
    'Building Materials',
    'Hand Tools',
    'Power Tools',
    'Plumbing Supplies',
    'Electrical Supplies',
    'Paints & Finishes',
    'Fasteners & Fittings',
    'Safety Equipment',
  ],
  'Sports & Outdoor': [
    'Gym & Fitness Equipment',
    'Bicycles & Accessories',
    'Sportswear',
    'Outdoor & Camping Gear',
    'Team Sports Equipment',
    'Swimming Gear',
  ],
  'Toys, Kids & Baby Products': [
    'Toys & Games',
    'Baby Clothing',
    'Baby Gear',
    'Feeding & Nursing',
    'Diapers & Baby Care',
    'Educational Toys',
    'School Supplies',
  ],
  'Pets & Animals': [
    'Pet Food',
    'Pet Accessories',
    'Pet Grooming Supplies',
    'Aquarium & Fish Supplies',
    'Pet Health & Wellness',
    'Pet Carriers & Housing',
    'Veterinary Services',
  ],
  'Repair & Technical Services': [
    'Phone & Tablet Repair',
    'Laptop & Computer Repair',
    'TV & Electronics Repair',
    'Home Appliance Repair',
    'Vehicle Repair & Mechanic Services',
    'Watch & Jewelry Repair',
    'Shoe & Bag Repair',
    'Furniture Repair & Upholstery',
  ],
  'Home & Trade Services': [
    'Plumbing Services',
    'Electrical Installation & Repair',
    'Carpentry & Furniture Making',
    'Painting Services',
    'Masonry Services',
    'Welding & Metal Fabrication',
    'Pest Control & Fumigation',
    'Handyman Services',
  ],
  'Cleaning Services': [
    'House Cleaning',
    'Office Cleaning',
    'Carpet & Sofa Cleaning',
    'Fumigation Services',
    'Laundry & Dry Cleaning',
    'Post-Construction Cleaning',
    'Compound & Garden Cleaning',
  ],
  'Beauty, Salon & Spa Services': [
    'Hair Styling & Braiding',
    'Barbershop Services',
    'Nail Technician Services',
    'Makeup Artist Services',
    'Spa & Massage Therapy',
    'Eyelash & Eyebrow Services',
    'Mobile Beauty Services',
  ],
  'Events, Photography & Entertainment Services': [
    'Photography & Videography',
    'Event Planning & Decor',
    'DJ & MC Services',
    'Catering Services',
    'Wedding Planning',
    'Sound & Stage Hire',
    'Tent, Chair & Furniture Hire',
    'Live Band & Entertainment',
  ],
  'Transport, Moving & Logistics Services': [
    'Movers & Packers',
    'Courier & Delivery Services',
    'Trailer & Truck Hire',
    'Car Hire & Chauffeur Services',
    'Boda Boda & Taxi Services',
    'Freight & Cargo Services',
  ],
  'Professional & Business Services': [
    'Legal Services',
    'Accounting & Tax Services',
    'Business Consulting',
    'Graphic Design & Branding',
    'Web & Software Development',
    'Printing & Signage',
    'Translation Services',
    'Recruitment & HR Services',
  ],
  'Health, Fitness & Wellness Services': [
    'Personal Training',
    'Physiotherapy',
    'Nutrition & Diet Consulting',
    'Home Nursing & Caregiving',
    'Counseling & Therapy',
    'Massage Therapy',
    'Mobile Veterinary Services',
  ],
  'Education & Training Services': [
    'Private Tutoring',
    'Driving Lessons',
    'Music Lessons',
    'Vocational Training',
    'Language Classes',
    'Exam Coaching',
    'Computer & Digital Skills Training',
  ],
  'Construction & Contracting Services': [
    'General Contracting',
    'Architecture & Design Services',
    'Interior Design',
    'Landscaping & Gardening',
    'Solar Installation',
    'Borehole Drilling',
    'Roofing Services',
  ],
};

/// Real curated list for a business type, or empty when unrecognized
/// (e.g. "Other") — never invented here.
List<String> categoriesForBusinessType(String? businessType) {
  if (businessType == null || businessType.isEmpty) return const [];
  return kBusinessTypeCategories[businessType] ?? const [];
}

/// The 10 business types that are 100% service businesses by definition —
/// ported from storeflow's SERVICE_ONLY_BUSINESS_TYPES
/// (business-type-taxonomy.ts). Used to pre-set (never silently decide) the
/// "physical product" toggle when creating a new product — see
/// product_editor_screen.dart's `_applyShippingDefaultForNewProduct`.
const List<String> kServiceOnlyBusinessTypes = [
  'Repair & Technical Services',
  'Home & Trade Services',
  'Cleaning Services',
  'Beauty, Salon & Spa Services',
  'Events, Photography & Entertainment Services',
  'Transport, Moving & Logistics Services',
  'Professional & Business Services',
  'Health, Fitness & Wellness Services',
  'Education & Training Services',
  'Construction & Contracting Services',
];

bool isServiceOnlyBusinessType(String? businessType) {
  if (businessType == null || businessType.isEmpty) return false;
  return kServiceOnlyBusinessTypes.contains(businessType);
}
