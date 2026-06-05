# DuitWise 💰

[![Website](https://img.shields.io/badge/Website-duitwise.app-blue)](https://www.duitwise.app/)
[![GitHub](https://img.shields.io/badge/GitHub-qiphy%2Fduitwise-black)](https://github.com/qiphy/duitwise)

> **Empowering the next generation with financial literacy through gamification and AI**

DuitWise is a gamified financial literacy app that transforms how children learn about saving, budgeting, and smart spending. With AI-driven insights and comprehensive parental oversight, we're cultivating a generation that is financially capable, scam-aware, and ready for the digital economy.

---

## 🎯 The Problem

Financial education is often too complex for children to apply in daily life. Existing platforms are either:
- **Too boring** - causing kids to tune out
- **Too technical** - making concepts inaccessible
- **Lacking visibility** - leaving parents in the dark about their children's spending habits in an increasingly digital world

## 💡 Our Solution

DuitWise bridges the gap between traditional financial education and modern digital learning by:

- 🎮 **Gamified Learning** - Replacing dry lectures with interactive missions
- 🤖 **AI-Powered Tools** - Personalized educational videos and spending analysis
- 📊 **Visual Reports** - Data visualization that kids actually understand
- 👨‍👩‍👧‍👦 **Parental Oversight Cockpit** - Complete visibility and control for parents
- 🎯 **Goal-Oriented Approach** - Making financial literacy a daily, interactive habit

---

## ✨ Key Features

### For Children

#### 🎯 Goal Setting & Tracking
- Set personal financial goals (toys, gadgets, experiences)
- Visual progress tracking on an interactive dashboard
- Real-time updates on savings and spending

#### 💼 Mission Hub - "Earning with Purpose"
- Parent-assigned tasks with clear rewards
- **Proof-of-Work** feature - submit photos to verify task completion
- Transform chores into a tangible financial journey
- Learn the value of active earning vs. passive receiving

#### 📚 AI-Powered Financial Education
- Daily AI-generated educational videos tailored to children's comprehension level
- Interactive quizzes with reward incentives
- Age-appropriate financial concepts
- Parent-controlled scheduling

#### 📈 AI Visual Reports
- Monthly AI-generated spending analysis
- Data transformed into engaging stories and charts
- Actionable insights for behavior adjustment
- Real-time habit tracking

### For Parents

#### 🎛️ Financial Cockpit
- Real-time view of child's financial status
- Comprehensive spending pattern analytics
- **Task & Reward Management** - Create and customize challenges
- **Bank Integration** - Secure reward transfers
- Data-backed conversation tools
- Guided coaching interface

---

## 🔄 How It Works

1. **Onboarding** - Child receives AI-tailored introduction video
2. **Goal Definition** - Child sets financial goals, synced to parent's device
3. **Dashboard Access** - View savings, progress, and available missions
4. **Earning & Spending** - Complete tasks, track expenses, build habits
5. **AI Analysis** - Monthly reports generated for both child and parent
6. **Adjustment & Growth** - Parents adjust allowances based on data insights

---

## 📊 Database Schema

DuitWise uses a comprehensive PostgreSQL database schema hosted on Supabase:

### Core Tables

**Profiles** - User accounts (both parents and children)
- Tracks user role, XP, streak, onboarding status
- Parent-child relationships via `parent_id`
- Banking integration fields

**Wallets** - Triple-jar money management system
- `save_balance` - Long-term savings
- `spend_balance` - Available spending money
- `share_balance` - Charitable giving
- `total_balance` - Computed total (stored generated column)

**Savings Goals** - Financial targets for children
- Goal name, target amount, current progress
- Status tracking (active/completed/cancelled)

**Tasks** - Parent-assigned missions with rewards
- Title, reward amount, status tracking
- Proof-of-Work image URL for task verification
- Status flow: assigned → submitted → completed

**Transactions** - Financial activity tracking
- Records all spending, earning, and saving activities
- Categorized for AI analysis and reporting
- Timestamped for historical tracking

**Quests** - Educational financial scenarios
- Story-based learning with choices
- Multiple outcomes based on decisions
- XP rewards for completion

**User Tokens** - Push notification management
- FCM tokens for mobile notifications
- Reminder and update delivery

### Key Features

✅ **Row Level Security (RLS)** - Ensures data privacy between families  
✅ **Indexed Queries** - Optimized for performance at scale  
✅ **Referential Integrity** - CASCADE deletes maintain data consistency  
✅ **Computed Columns** - Auto-calculated totals for wallet balances  
✅ **Timestamp Tracking** - Full audit trail for all financial activities

---

## 🛠️ Tech Stack

### Frontend
- **Flutter** with **Dart** - Cross-platform UI (iOS & Android)
- Single codebase with responsive, gamified animations
- Fluid, engaging user experience across all devices

### Backend
- **Supabase** - Primary infrastructure
  - Hosted PostgreSQL database
  - Real-time user data management
  - Secure authentication
  - File storage for Proof-of-Work photos
  
- **FastAPI** (Python) - High-performance backend engine
  - Complex financial logic processing
  - User data handling
  - AI layer integration

### AI Layer
- **OpenRouter API** - Unified AI gateway
  - Dynamic request routing
  - Multi-model performance comparison
  - Access to leading AI language models
  - Powers personalized video scripts, spending analysis, and visual reports

---

## 📱 User Journey: Ali's Story

**Day 1 - The Goal**
> Ali, age 12, wants a Batman Lego set. He opens DuitWise and realizes money is finite. Time for a plan.

**Week 1-4 - Earning Phase**
> Through the Mission Hub, Ali's mother assigns tasks: mowing the lawn, tidying the garage. Each task requires photo proof and offers clear rewards. Ali learns the value of his own work.

**Daily - Education**
> Ali receives daily AI-generated financial videos at a set time. Correct quiz answers earn rewards. Knowledge builds daily.

**Month End - Insight**
> Instead of a confusing bank statement, Ali gets an AI Visual Report showing how frequent snack purchases delayed his goal. Charts make it clear.

**The Win**
> With data-backed guidance from his mother's Financial Cockpit, Ali adjusts his spending. Buying the Lego set becomes a reward for patience and discipline—not an impulse.

**The Result**
> Ali achieves his goal AND builds lasting financial responsibility.

---

## 🚀 Roadmap

### Phase 1: Full Banking Integration
Moving beyond tracking to becoming a fully operational transaction layer, allowing kids to manage real money in a secure, parent-monitored environment.

### Phase 2: Regulatory Excellence
Pursuing formal financial licensing to provide institutional-grade security for every family as we scale.

### Phase 3: Global Certification
Working toward AI-curriculum certification by financial regulators, positioning DuitWise as the global gold standard for financial literacy.

---

## 🎯 Our Mission

We're cultivating a generation of financial strategists who understand the value of money before they ever touch a credit card. 

In a financially literate society:
- ✅ Fraud and scam risks are minimized
- ✅ Digital finance adoption thrives
- ✅ Children grow into financially responsible adults
- ✅ Parents have the tools to guide with confidence

---

## 🔒 Security & Privacy

- Bank-grade encryption for all transactions
- Parental control at every level
- Secure Proof-of-Work photo storage
- Real-time data synchronization with privacy safeguards
- Compliance-ready architecture for financial licensing

---

## 🌐 Links

- **Website**: [www.duitwise.app](https://www.duitwise.app/)
- **GitHub**: [github.com/qiphy/duitwise](https://github.com/qiphy/duitwise)

---

## 👥 Team

**SudoFin** - Building the future of financial literacy, one child at a time.

---

## 📄 License

[Add your license information here]

---

## AI Tools Used

### 1. Gemini (Google)
* **Application:** Primary Code Generation, Core Architecture Design, and Logic Refinement.
* **Utilization:** Used extensively as the primary conversational engineering partner to generate asynchronous FastAPI endpoints, configure relational Supabase database schemas, validate Pydantic data models, and structure manual Flutter UI components.

### 2. ChatGPT (OpenAI)
* **Application:** Micro-Feature Engineering.
* **Utilization:** Deployed to rapidly generate minor utility functions, handle isolated algorithmic calculations, and refine small front-end features within the Flutter client codebase.

### 3. Claude (Anthropic)
* **Application:** System Documentation and Structuring.
* **Utilization:** Utilized to analyze repository configurations, format structural outputs, and generate comprehensive documentation, including this technical README architecture layout.

### Human Oversight & Code Defense
Every system state, endpoint routing, database constraint, and UI widget generated by these models was manually reviewed, integrated, and thoroughly verified by the developer.

## 🚀 Installation & Setup

### 🚀 Quick Start

**New to DuitWise? Follow these steps:**

1. **Clone the repository**
   ```bash
   git clone https://github.com/qiphy/duitwise.git
   cd duitwise
   ```

2. **Set up Supabase** (see detailed instructions below)
   - Create a Supabase project
   - Run the SQL schema
   - Get your credentials

3. **Configure the app**
   - Update `lib/services/supabase_service.dart` with your Supabase URL and keys
   - Update `backendBaseUrl` based on your environment

4. **Install dependencies**
   ```bash
   cd app
   flutter pub get
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

---

### 📋 Detailed Installation

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.0 or higher) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (included with Flutter)
- **Python** (3.9 or higher) - For backend services
- **Git** - Version control
- **Android Studio** / **Xcode** - For mobile development
- **Node.js** (Optional) - For additional tooling

### Backend Setup

#### 1. Clone the Repository

```bash
git clone https://github.com/qiphy/duitwise.git
cd duitwise
```

#### 2. Set Up Python Backend

```bash
# Navigate to backend directory
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

#### 3. Configure Environment Variables

Create a `.env` file in the backend directory:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_project_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_role_key

# OpenRouter API Configuration
OPENROUTER_API_KEY=your_openrouter_api_key

# Database Configuration
DATABASE_URL=your_postgresql_connection_string

# JWT Secret
JWT_SECRET=your_jwt_secret_key

# Application Settings
ENVIRONMENT=development
DEBUG=True
```

#### 4. Initialize Database

```bash
# Run database migrations
python manage.py migrate

# Or if using Supabase, run SQL migrations in Supabase dashboard
```

#### 5. Start Backend Server

```bash
# Start FastAPI server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The backend API will be available at `http://localhost:8000`

### Frontend Setup

#### 1. Navigate to Flutter App Directory

```bash
cd ../app
# or from root: cd app
```

#### 2. Install Flutter Dependencies

```bash
flutter pub get
```

#### 3. Configure Environment Variables

Create a `lib/config/env.dart` file:

```dart
class Environment {
  static const String apiBaseUrl = 'http://localhost:8000';
  static const String supabaseUrl = 'your_supabase_project_url';
  static const String supabaseAnonKey = 'your_supabase_anon_key';
  
  // Add other configuration as needed
}
```

**Or update the existing `lib/services/supabase_service.dart` file:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  // IMPORTANT: Replace these with your actual values
  // For local development, use your local IP or 10.0.2.2 for Android Emulator
  // For production, use your deployed backend URL
  final String backendBaseUrl = 'http://localhost:8000'; // Change this
  
  Future<void> initialize() async {
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_PROJECT_URL', // Change this
      anonKey: 'YOUR_SUPABASE_ANON_KEY', // Change this
    );
  }

  SupabaseClient get client => Supabase.instance.client;
  
  String? get currentUserId => client.auth.currentUser?.id;
}

final supabaseService = SupabaseService();
```

**To get your Supabase credentials:**
1. Go to your Supabase project dashboard
2. Click on **Settings** → **API**
3. Copy the **Project URL** (for `url`)
4. Copy the **anon public** key (for `anonKey`)

**Backend URL options:**
- **Local development**: `http://localhost:8000`
- **Android Emulator**: `http://10.0.2.2:8000`
- **Physical device on same network**: `http://YOUR_LOCAL_IP:8000` (find your IP with `ipconfig` or `ifconfig`)
- **Production**: Your deployed backend URL (e.g., Render, Railway, AWS)

Or create a `.env` file in the app root:

```env
API_BASE_URL=http://localhost:8000
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

#### 4. Run the Application

```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Or run on all connected devices
flutter run

# For web
flutter run -d chrome

# For iOS (macOS only)
flutter run -d ios

# For Android
flutter run -d android
```

### Development Mode

#### Running Both Backend and Frontend

**Terminal 1 - Backend:**
```bash
cd backend
source venv/bin/activate  # or venv\Scripts\activate on Windows
uvicorn main:app --reload --port 8000
```

**Terminal 2 - Frontend:**
```bash
cd app
flutter run
```

### Building for Production

#### Android APK

```bash
flutter build apk --release
```

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

#### iOS IPA (macOS only)

```bash
flutter build ios --release
```

Then use Xcode to archive and distribute.

#### Web

```bash
flutter build web --release
```

The build will be available in `build/web/`

### Supabase Setup

1. **Create a Supabase Project**
   - Go to [supabase.com](https://supabase.com)
   - Create a new project
   - Note your Project URL and anon key

2. **Set Up Database Tables**
   
   Run these SQL commands in Supabase SQL Editor:

   ```sql
   -- Create custom enum type for user roles
   CREATE TYPE user_role AS ENUM ('parent', 'child');

   -- Profiles table (main user table)
   CREATE TABLE profiles (
     id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
     username TEXT NOT NULL,
     xp INTEGER DEFAULT 0,
     streak INTEGER DEFAULT 0,
     last_active DATE,
     role user_role NOT NULL DEFAULT 'child',
     parent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
     is_approved BOOLEAN NOT NULL DEFAULT FALSE,
     email TEXT,
     linked_bank_name TEXT,
     bank_account_number TEXT,
     completed_tasks_count INTEGER DEFAULT 0,
     earned_badges_count INTEGER DEFAULT 0,
     has_completed_onboarding BOOLEAN NOT NULL DEFAULT FALSE
   );

   -- Wallets table (triple-jar system: Save, Spend, Share)
   CREATE TABLE wallets (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
     save_balance NUMERIC DEFAULT 0.00,
     spend_balance NUMERIC DEFAULT 0.00,
     share_balance NUMERIC DEFAULT 0.00,
     total_balance NUMERIC GENERATED ALWAYS AS (save_balance + spend_balance + share_balance) STORED
   );

   -- Savings goals table
   CREATE TABLE savings_goals (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
     goal_name TEXT NOT NULL DEFAULT 'My Savings Goal',
     target_amount NUMERIC NOT NULL,
     current_amount NUMERIC DEFAULT 0.00,
     status TEXT DEFAULT 'active',
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
   );

   -- Tasks table (parent-assigned missions)
   CREATE TABLE tasks (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
     title TEXT NOT NULL,
     reward_amount NUMERIC NOT NULL,
     status TEXT NOT NULL DEFAULT 'assigned',
     proof_url TEXT,
     assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
   );

   -- Transactions table (spending, earning, saving tracking)
   CREATE TABLE transactions (
     id BIGSERIAL PRIMARY KEY,
     profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
     title TEXT NOT NULL,
     amount NUMERIC NOT NULL,
     category TEXT NOT NULL,
     type TEXT NOT NULL DEFAULT 'spend',
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
   );

   -- Quests table (educational financial scenarios)
   CREATE TABLE quests (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     title TEXT NOT NULL,
     story TEXT NOT NULL,
     choice_a TEXT NOT NULL,
     choice_b TEXT NOT NULL,
     outcome_a TEXT NOT NULL,
     outcome_b TEXT NOT NULL,
     reward_xp INTEGER DEFAULT 50
   );

   -- User tokens table (for push notifications)
   CREATE TABLE user_tokens (
     id BIGSERIAL PRIMARY KEY,
     user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
     fcm_token TEXT NOT NULL,
     updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
   );

   -- Create indexes for better query performance
   CREATE INDEX idx_profiles_parent_id ON profiles(parent_id);
   CREATE INDEX idx_profiles_role ON profiles(role);
   CREATE INDEX idx_wallets_profile_id ON wallets(profile_id);
   CREATE INDEX idx_savings_goals_profile_id ON savings_goals(profile_id);
   CREATE INDEX idx_tasks_profile_id ON tasks(profile_id);
   CREATE INDEX idx_tasks_status ON tasks(status);
   CREATE INDEX idx_transactions_profile_id ON transactions(profile_id);
   CREATE INDEX idx_transactions_created_at ON transactions(created_at);
   CREATE INDEX idx_user_tokens_user_id ON user_tokens(user_id);

   -- Enable Row Level Security (RLS)
   ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
   ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
   ALTER TABLE savings_goals ENABLE ROW LEVEL SECURITY;
   ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
   ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
   ALTER TABLE quests ENABLE ROW LEVEL SECURITY;
   ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;

   -- RLS Policies for profiles
   CREATE POLICY "Users can view their own profile" ON profiles
     FOR SELECT USING (auth.uid() = id);

   CREATE POLICY "Parents can view their children's profiles" ON profiles
     FOR SELECT USING (auth.uid() = parent_id);

   CREATE POLICY "Users can update their own profile" ON profiles
     FOR UPDATE USING (auth.uid() = id);

   -- RLS Policies for wallets
   CREATE POLICY "Users can view their own wallet" ON wallets
     FOR SELECT USING (profile_id = auth.uid());

   CREATE POLICY "Parents can view their children's wallets" ON wallets
     FOR SELECT USING (
       profile_id IN (
         SELECT id FROM profiles WHERE parent_id = auth.uid()
       )
     );

   -- RLS Policies for savings_goals
   CREATE POLICY "Users can manage their own goals" ON savings_goals
     FOR ALL USING (profile_id = auth.uid());

   CREATE POLICY "Parents can view their children's goals" ON savings_goals
     FOR SELECT USING (
       profile_id IN (
         SELECT id FROM profiles WHERE parent_id = auth.uid()
       )
     );

   -- RLS Policies for tasks
   CREATE POLICY "Users can view their own tasks" ON tasks
     FOR SELECT USING (profile_id = auth.uid());

   CREATE POLICY "Children can update task proof" ON tasks
     FOR UPDATE USING (profile_id = auth.uid());

   CREATE POLICY "Parents can manage their children's tasks" ON tasks
     FOR ALL USING (
       profile_id IN (
         SELECT id FROM profiles WHERE parent_id = auth.uid()
       )
     );

   -- RLS Policies for transactions
   CREATE POLICY "Users can view their own transactions" ON transactions
     FOR SELECT USING (profile_id = auth.uid());

   CREATE POLICY "Parents can view their children's transactions" ON transactions
     FOR SELECT USING (
       profile_id IN (
         SELECT id FROM profiles WHERE parent_id = auth.uid()
       )
     );

   -- RLS Policies for quests (public read)
   CREATE POLICY "Anyone can view quests" ON quests
     FOR SELECT USING (true);
   ```

3. **Configure Storage Buckets**
   - Create a bucket named `task-proofs` for Proof-of-Work images
   - Set appropriate access policies

### OpenRouter API Setup

1. Sign up at [openrouter.ai](https://openrouter.ai)
2. Generate an API key
3. Add the key to your `.env` file
4. Configure model preferences in your backend settings

### Testing

#### Backend Tests

```bash
cd backend
pytest tests/
```

#### Frontend Tests

```bash
cd app
flutter test
```

#### Integration Tests

```bash
flutter test integration_test/
```

### Troubleshooting

**Flutter version issues:**
```bash
flutter doctor
flutter upgrade
```

**Dependency conflicts:**
```bash
flutter clean
flutter pub get
```

**Backend issues:**
```bash
# Check Python version
python --version

# Reinstall dependencies
pip install -r requirements.txt --force-reinstall
```

**Database connection issues:**
- Verify your Supabase credentials
- Check firewall settings
- Ensure database is accessible from your IP

### Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com)
- [Supabase Documentation](https://supabase.com/docs)
- [OpenRouter Documentation](https://openrouter.ai/docs)

---

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines for more information.

---

## 📧 Contact

For inquiries, partnerships, or support, please visit [www.duitwise.app](https://www.duitwise.app/)

---

<div align="center">
  
**DuitWise** - *Making financial learning fun, one mission at a time* 🚀

*Empowering children. Enabling parents. Building futures.*

</div>
