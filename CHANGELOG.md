# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning v2.0.0](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - In Progress

### Changed

- Configure VNET and two subnets: VM subnet and SQL Server subnet
- Configure Azure Linux VM to validate connection with SQL server
- Configure Azure SQL server
- Configure Private Endpoint inside SQL subnet
- Configure Private DNS zone
- Associate Private DNS zone with VNET
- Create DNS name using Private Endpoint non-public IP address
- Validate solution using `nslookup`
