# Learn2Earn Pools

A study-to-earn platform where students complete verified micro-learning modules and receive STX token rewards automatically via smart contracts.

## Features

- **Module Creation**: Educators create learning modules with reward amounts
- **Reward Pool**: Community funds a shared reward pool for learners
- **Completion Tracking**: Automatic reward distribution upon module completion
- **User Statistics**: Track learning progress and earnings

## Contract Functions

### Public Functions
- `fund-pool(amount)` - Add STX to the reward pool
- `create-module(title, reward-amount)` - Create a new learning module
- `complete-module(module-id)` - Complete a module and claim rewards
- `deactivate-module(module-id)` - Deactivate a module (creator only)

### Read-Only Functions
- `get-module(module-id)` - Get module details
- `get-user-completion(user, module-id)` - Check if user completed module
- `get-user-stats(user)` - Get user's learning statistics
- `get-reward-pool()` - Get current reward pool balance

## Usage

1. Community funds the reward pool
2. Educators create learning modules
3. Students complete modules and automatically receive rewards
4. Track progress and earnings through user statistics