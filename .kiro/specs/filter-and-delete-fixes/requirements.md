# Requirements Document

## Introduction

This feature addresses three specific improvements to the Farm Pro application's reporting and sales management functionality:

1. **Exact Member Number Filtering in Crop Search**: Update the member number filter in the Crop Search screen to use exact matching instead of partial matching for more precise search results.

2. **Sale Deletion with Stock Adjustment**: Add the ability to delete sales transactions from the Sales Report screen with automatic stock adjustment to maintain inventory accuracy.

3. **Exact Member Number Search in Sales Report**: Update the search functionality in the Sales Report screen to search by member number only (removing receipt number search) and use exact matching.

These improvements will enhance data accuracy, provide better inventory management capabilities, and improve the user experience when searching for specific member transactions.

## Requirements

### Requirement 1: Exact Member Number Filtering in Crop Search Screen

**User Story:** As a farm administrator, I want to filter crop collections by exact member number, so that I can view collections for a specific member without seeing partial matches from other members.

#### Acceptance Criteria

1. WHEN a user enters a member number in the member number filter field THEN the system SHALL filter collections to show only those with an exact match to the entered member number
2. WHEN a user enters "123" in the member number filter THEN the system SHALL show only collections with member number "123" and SHALL NOT show collections with member numbers like "1234" or "0123"
3. WHEN the member number filter field is empty THEN the system SHALL display all collections without member number filtering
4. WHEN a user clears the member number filter THEN the system SHALL immediately refresh the collections list to show all collections

### Requirement 2: Sale Deletion with Stock Adjustment in Sales Report Screen

**User Story:** As a farm administrator, I want to delete incorrect or cancelled sales transactions, so that I can maintain accurate sales records and ensure inventory levels are correctly adjusted.

#### Acceptance Criteria

1. WHEN a user views a sale in the sales report table THEN the system SHALL display a delete action button for each sale row
2. WHEN a user clicks the delete button for a sale THEN the system SHALL display a confirmation dialog asking the user to confirm the deletion
3. WHEN a user confirms the deletion THEN the system SHALL restore the stock quantities for all products in the sale by adding back the sold quantities
4. WHEN a user confirms the deletion THEN the system SHALL mark the sale as inactive (soft delete) in the database
5. WHEN a sale is successfully deleted THEN the system SHALL refresh the sales list and display a success message
6. WHEN a sale deletion fails THEN the system SHALL display an error message and SHALL NOT modify any stock quantities
7. WHEN stock is adjusted due to sale deletion THEN the system SHALL create stock movement records for audit purposes
8. WHEN a sale with multiple items is deleted THEN the system SHALL adjust stock for all items in the sale transaction

### Requirement 3: Exact Member Number Search in Sales Report Screen

**User Story:** As a farm administrator, I want to search sales by exact member number only, so that I can quickly find all sales for a specific member without confusion from partial matches or receipt numbers.

#### Acceptance Criteria

1. WHEN a user enters a value in the search field THEN the system SHALL filter sales to show only those with an exact match to the member number
2. WHEN a user enters "123" in the search field THEN the system SHALL show only sales with member number "123" and SHALL NOT show sales with member numbers like "1234" or "0123"
3. WHEN a user enters a value in the search field THEN the system SHALL NOT search by receipt number
4. WHEN the search field is empty THEN the system SHALL display all sales without filtering by member number
5. WHEN a user clears the search field THEN the system SHALL immediately refresh the sales list to show all sales
6. WHEN the search field placeholder text is displayed THEN it SHALL indicate "Search by member number" to guide users
