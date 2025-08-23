# SAS Clinical Macros CI/CD Project

A comprehensive CI/CD pipeline for SAS macros in clinical programming, integrated with SAS Viya for automated testing, validation, and deployment.

## 🚀 Features

- **Automated Testing**: Unit and integration tests for SAS macros
- **SAS Viya Integration**: Direct execution and validation on SAS Viya platform
- **YAML-based Documentation**: Structured macro documentation with semantic search
- **CI/CD Pipelines**: Both GitHub Actions and GitLab CI support
- **CDISC Compliance**: Built-in validation for SDTM and ADaM standards
- **Automated Documentation**: Self-generating documentation with embeddings-based search

## 📁 Project Structure

```
sas-clinical-macros/
├── macros/                 # SAS macro library
│   ├── demog_summary.sas  # Demographics summary macro
│   ├── ae_summary.sas     # Adverse events summary macro
│   └── validate_data.sas  # Data validation macro
├── tests/                  # Test suite
│   ├── test_runner.sas    # Main test execution framework
│   └── test_*.sas         # Individual test files
├── viya/                   # SAS Viya integration
│   ├── sas_viya_config.yaml
│   └── viya_job_executor.py
├── docs/                   # Documentation
│   ├── generate_docs.py   # Documentation generator
│   └── search_api.py      # Semantic search API
├── .github/workflows/      # GitHub Actions CI/CD
└── .gitlab/               # GitLab CI/CD
```

## 🔧 Setup Instructions

### Prerequisites

1. **SAS Viya License**: Active SAS Viya environment
2. **Python 3.8+**: For automation scripts
3. **Git**: Version control
4. **Docker** (optional): For containerized deployment

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/sas-clinical-macros.git
cd sas-clinical-macros
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

3. Configure SAS Viya connection:
```bash
# Copy and edit the SASJS configuration file (recommended)
cp .sasjsrc.template .sasjsrc
# Edit with your SAS Viya credentials

# OR use Python configuration (alternative)
cp viya/sas_viya_config.yaml.template viya/sas_viya_config.yaml
```

4. Set environment variables:
```bash
export SAS_VIYA_URL=https://your-viya-server.com
export SAS_USERNAME=your-username
export SAS_PASSWORD=your-password
export SAS_CLIENT_ID=your-client-id
export SAS_CLIENT_SECRET=your-client-secret
export CAS_SERVER=your-cas-server
```

## 📝 Macro Documentation Format

Each SAS macro should include a YAML header for automated documentation:

```sas
/******************************************************************************
---
name: macro_name
description: Brief description of the macro
category: category_name
tags: [tag1, tag2, tag3]
version: 1.0.0
parameters:
  - name: param1
    type: dataset
    required: true
    description: Parameter description
    example: work.dataset
returns:
  - type: dataset
    description: Output description
examples:
  - code: |
      %macro_name(param1=value);
    description: Example usage
---
******************************************************************************/
```

## 🔄 CI/CD Workflows

### GitHub Actions

The pipeline automatically triggers on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual workflow dispatch

Stages:
1. **Validate**: Syntax and YAML header validation
2. **Test**: Unit and integration tests on SAS Viya
3. **Quality**: Code quality and security checks
4. **Documentation**: Generate and deploy documentation
5. **Deploy**: Deploy to dev/test/prod environments

### GitLab CI

Similar pipeline with GitLab-specific features:
- GitLab Pages for documentation
- Environment-specific deployments
- Manual production deployment with rollback

## 🧪 Testing

### Running Tests Locally

```bash
# Run all tests
python viya/viya_job_executor.py --run-tests

# Run specific test
python viya/viya_job_executor.py --test tests/test_demog_summary.sas

# Validate macros only
python viya/viya_job_executor.py --validate-only
```

### Writing Tests

Create test files in the `tests/` directory:

```sas
/* tests/test_my_macro.sas */
/* Test data setup */
data test_input;
    /* ... */
run;

/* Execute macro */
%my_macro(indata=test_input, outdata=test_output);

/* Validate results */
%if not %sysfunc(exist(test_output)) %then %do;
    %let status = FAIL;
    %let message = Output dataset not created;
%end;
```

## 📊 Documentation Generation

### Generate Documentation

```bash
cd docs
python generate_docs.py
```

This creates:
- `index.html`: Interactive HTML documentation
- `README.md`: Markdown documentation
- `embeddings.pkl`: Search index for semantic search

### Start Search API

```bash
cd docs
python search_api.py
```

Access the API at `http://localhost:5000`

### Search API Endpoints

- `POST /api/search`: Semantic search for macros
- `GET /api/macros`: List all macros
- `GET /api/macro/<name>`: Get specific macro documentation

## 🚀 Deployment

### Manual Deployment

```bash
# Deploy to development
python viya/viya_job_executor.py --deploy --env dev

# Deploy to production (requires approval)
python viya/viya_job_executor.py --deploy --env prod
```

### Automated Deployment

Deployments are automated through CI/CD pipelines:
- **Development**: Auto-deploy on push to `develop`
- **Test**: Auto-deploy on push to `main`
- **Production**: Manual approval required

## 🔒 Security Considerations

1. **Credentials**: Never commit credentials to the repository
2. **Secrets Management**: Use GitHub/GitLab secrets for sensitive data
3. **Access Control**: Configure SAS Viya permissions appropriately
4. **Code Review**: All changes require PR/MR review
5. **Audit Trail**: All deployments are logged and traceable

## 📈 Monitoring

### Pipeline Metrics

- Test pass rate
- Code coverage
- Deployment frequency
- Mean time to recovery (MTTR)

### SAS Viya Monitoring

Monitor through SAS Viya Environment Manager:
- Job execution times
- Resource utilization
- Error rates
- User access logs

## 🛠 Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Check SAS Viya credentials
   - Verify network connectivity
   - Check OAuth2 client configuration

2. **Tests Failing**
   - Review test logs in `logs/` directory
   - Check SAS Viya job logs
   - Verify test data availability

3. **Deployment Issues**
   - Check folder permissions in SAS Viya
   - Verify compute context availability
   - Review deployment logs

## 📚 Additional Resources

- [SAS Viya Documentation](https://documentation.sas.com/viya)
- [CDISC Standards](https://www.cdisc.org/standards)
- [Clinical Programming Best Practices](https://www.phuse.eu/best-practices)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new macros
4. Update documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see LICENSE file for details.

## 👥 Team

- Clinical Programming Team
- Data Science Team
- IT Operations Team

## 📞 Support

For issues or questions:
- Create an issue in the repository
- Contact: clinical-programming-team@company.com
- Internal Wiki: https://wiki.company.com/sas-macros