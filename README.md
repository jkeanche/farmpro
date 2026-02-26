# Coffee Pro - Coffee Society Management System

A comprehensive Flutter application for managing coffee societies, collections, inventory, and sales operations.

## 🌟 Features

### ☕ Coffee Collection Management

- **Seasonal Operations**: Yearly coffee seasons (2024/2025 format) with start/end dates
- **Product Selection**: Cherry or Mbuni selection with lock mechanism once collection starts
- **Weight Management**: Gross, tare, and net weight calculations
- **Receipt Generation**: Automated receipt printing and SMS notifications
- **Manual/Scale Entry**: Support for both manual entry and scale integration

### 👥 Member Management

- Complete member registration and management
- Member profiles with contact information
- Collection history and reporting
- Route-based organization

### 📦 Inventory Management

- **Product Categories**: Organize products by categories (fertilizers, pesticides, equipment, etc.)
- **Units of Measure**: Flexible measurement units (kg, liters, pieces, etc.)
- **Stock Management**: Track inventory levels with stock movements
- **Product Catalog**: Comprehensive product database with pricing

### 💰 Sales & Credit System

- **Cash Sales**: Immediate payment transactions
- **Credit Sales**: Member credit accounts with repayment tracking
- **Partial Sales**: Support for partial quantity sales
- **Payment History**: Complete repayment tracking and history

### 📊 Reporting & Analytics

- Collection reports by date range, member, or season
- Sales reports with profit analysis
- Member collection summaries
- Inventory reports and stock levels
- Excel export functionality

### 🖨️ Printing & Notifications

- Receipt printing via Bluetooth thermal printers
- SMS notifications for collections and sales
- Export reports to Excel and PDF formats

### ⚙️ System Management

- **User Management**: Multi-user support with role-based access
- **Settings**: Configurable pricing, products, and system preferences
- **Season Management**: Create, activate, and close coffee seasons
- **Route Management**: Organize members by collection routes

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0 or higher)
- Android Studio or VS Code
- Android device or emulator

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd farm_pro
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

### Building for Production

```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

## 📱 App Structure

### Core Models

- **Season**: Coffee collection seasons with lifecycle management
- **CoffeeCollection**: Individual coffee collection records
- **Member**: Coffee society members
- **Product**: Inventory items with categories and units
- **Sale**: Sales transactions with items and payments
- **Stock**: Inventory level tracking

### Services

- **SeasonService**: Season management and operations
- **CoffeeCollectionService**: Collection processing and storage
- **InventoryService**: Product, stock, and sales management
- **MemberService**: Member data management
- **PrintService**: Receipt and document printing
- **SmsService**: SMS notifications and messaging

### Controllers (GetX)

- **SeasonController**: Season UI state management
- **CoffeeCollectionController**: Collection form handling
- **InventoryController**: Inventory operations
- **MemberController**: Member management
- **SettingsController**: System configuration

## 🎨 UI Themes

The app features a coffee-inspired design with:

- **Primary Colors**: Rich browns and chocolates
- **Accent Colors**: Warm coffee tones
- **Typography**: Clean, readable fonts
- **Icons**: Coffee and agriculture-themed iconography

## 🔧 Configuration

### System Settings

- Coffee price per kg
- Product type selection (Cherry/Mbuni)
- Currency settings
- Printer and scale configuration
- SMS gateway settings

### Database

- SQLite local database
- Automatic migrations
- Data backup and restore capabilities

## 📋 Usage Guide

### Setting Up a New Season

1. Navigate to Season Management
2. Create a new season with start/end dates
3. Activate the season for collections
4. Configure coffee product and pricing

### Recording Collections

1. Select member from dropdown
2. Enter or capture weights (gross/tare)
3. System calculates net weight and value
4. Generate receipt and send SMS notification

### Managing Inventory

1. Set up product categories and units
2. Add products with pricing and pack sizes
3. Manage stock levels with additions/deductions
4. Process sales (cash or credit)

### Processing Sales

1. Select products and quantities
2. Choose payment method (cash/credit)
3. Generate receipt and update inventory
4. Track credit repayments

## 🔒 Security Features

- User authentication and authorization
- Role-based access control
- Data encryption for sensitive information
- Audit trails for all transactions

## 📊 Reporting Features

- **Collection Reports**: Daily, weekly, monthly summaries
- **Member Reports**: Individual member collection history
- **Sales Reports**: Revenue and profit analysis
- **Inventory Reports**: Stock levels and movements
- **Financial Reports**: Credit accounts and repayments

## 🛠️ Technical Details

### Architecture

- **Framework**: Flutter with GetX state management
- **Database**: SQLite with custom ORM
- **Printing**: Bluetooth thermal printer integration
- **SMS**: Multiple gateway support
- **Export**: Excel and PDF generation

### Dependencies

- `get`: State management and dependency injection
- `sqflite`: Local database storage
- `path_provider`: File system access
- `permission_handler`: Device permissions
- `bluetooth_print`: Thermal printer support
- `excel`: Excel file generation
- `pdf`: PDF document creation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For support and questions:

- Email: support@coffeepro.app
- Documentation: [Wiki](link-to-wiki)
- Issues: [GitHub Issues](link-to-issues)

## 🔄 Version History

### v2.0.0 - Coffee Society Transformation

- Complete transformation from coffee to coffee collection system
- Added seasonal management
- Implemented comprehensive inventory system
- Added sales and credit management
- Enhanced reporting capabilities
- Improved UI with coffee-themed design

### v1.0.0 - Initial Release

- Basic coffee collection functionality
- Member management
- Simple reporting

---

**Coffee Pro** - Empowering Coffee Societies with Digital Solutions ☕
