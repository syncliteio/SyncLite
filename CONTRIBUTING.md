# Contributing to SyncLite

Thank you for considering contributing to SyncLite! We welcome all kinds of contributions, including:

- Building open-source data integration projects on top of SyncLite platform demonstrating interesting usecases
- Reporting issues and bugs
- Adding new integration tests
- Fixing issues and bugs
- Submitting new features and improvements
- Reviewing pull requests
- Improving documentation
- Providing feedback and suggestions

## Getting Started

1. **Fork the repository**: Start by forking the repository to your GitHub account.
2. **Clone your fork**: Clone the forked repository to your local machine.
    ```bash
    git clone https://github.com/YOUR-USERNAME/SyncLite.git
    ```
3. **Create a new branch**: Make a new branch for your feature or bug fix. Branches should be named following the convention:
    ```
    issue#<issue-number>
    ```
    For example, if you're working on issue #25, name your branch `issue#25`.
4. **Make changes**: Develop your feature, fix a bug, or improve documentation. Ensure the code adheres to the project's coding style.
5. **Test your changes**: Run the integration tests in the synclite-validator tool to ensure your changes are correct and don't break existing functionality.
6. **Commit your changes**: Write a meaningful commit message.
    ```bash
    git commit -m "Brief description of your changes"
    ```
7. **Push your changes**: Push your branch to GitHub.
    ```bash
    git push origin issue#<issue-number>
    ```
8. **Create a pull request**: Open a pull request from your forked repository and describe your changes. Please reference relevant issues if applicable.

## Issues

When opening issues, please prefix the title with `<project-name>:`

e.g. synclite-validator: Add new integration test for SyncLite QReader

Be as descriptive as possible, including steps to reproduce the issue if applicable.


## Code Style

Please follow the common conventions used in Java projects. Refer : [Google's Java Style Guide](https://google.github.io/styleguide/javaguide.html)).

## Code of Conduct

We expect contributors to follow our [Code of Conduct](./CODE_OF_CONDUCT.md) when participating in the project.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](./LICENSE).

