<img width="1198" height="598" alt="image" src="https://github.com/user-attachments/assets/9b9025fa-401a-491c-a07f-ec43b2e78d2f" />


Berlin Marketplace Analytics: Logistics & Retention

Project Overview:
This project provides an end-to-end business intelligence solution for the Berlin Marketplace dataset. By processing over 100k transactions, the analysis identifies a critical business paradox: despite a strong customer acquisition engine, the platform suffers from a low retention rate. The project investigates the correlation between delivery performance and customer satisfaction to provide actionable logistics recommendations for the Berlin-based e-commerce ecosystem.

Tools & Technologies:
  PostgreSQL: Data engineering, relational joins, and business logic (CTEs, Window Functions).

  Tableau Desktop: Advanced visualization, including Dual-Axis mapping and Strategic Heatmaps.

  GitHub: Version control and professional documentation.

Key Business Questions Explored:
  Customer Retention: Quantifying the "Leaky Bucket" effect and identifying repeat purchase behavior.

  Logistics vs. Sentiment: Mapping delivery time lag against customer review scores.

  Market Performance: Identifying high-revenue clusters and growth trends through Monthly-over-Monthly (MoM) analysis.

  Operational Efficiency: Pinpointing categories where shipping costs disproportionately impact product value.

Repository Structure:
Plaintext
├── SQL_Queries/
│   ├── berlin_marketplace_setup.sql  # Schema design, table creation, and data cleaning
├── Tableau_Workbook/
│   ├── Presentation_Deck.twb         # Interactive Tableau dashboard file
└── README.md                         # Project documentation

How to Run:
1. Database Setup (PostgreSQL)
Ensure you have a PostgreSQL instance running.

Execute berlin_marketplace_setup.sql. This script handles the creation of the relational schema, including tables for customers, geolocation, order items, payments, reviews, and products. The script includes pre-defined PRIMARY KEY and FOREIGN KEY constraints to ensure data integrity.

2. Visualization
Open Presentation_Deck.twb in Tableau Desktop.

The workbook is organized into several strategic views:

Loyalty Timeline: Tracking unique customer growth.

Happiness Matrix: Cross-referencing revenue (Size) with Avg Review Score (Color).

Shipping Efficiency: Bullet graphs comparing Order Price vs. Freight.

Note: Ensure the data source connection in Tableau points to your local PostgreSQL instance or the relevant CSV files.
