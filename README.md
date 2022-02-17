# Azure

Contains snippets of things that make working in Azure easier. Mix of ARM, PowerShell, and Terraform

## FAQs

- Why does your code call Azure Governement a lot?
  - Most of my customers are in Azure Government, which is a different instance of Azure than what you are probably using. But good news, Azure Government is generally 6 months behind Azure Global, so if it works for me it'll work for you. Just remove any reference to "Environment" and set your region accordingly.

- Why aren't there full featured scripts and templates?
    - The full scripts and ARM templates are full of customer data and are super customized for their needs. This is just small snippets of things that I use often and are big wins I've had
    
- Why are you doing this?
    - I have made a career out of finding random code on GitHub and blogs and modifying it for my customers needs, time to give back.
    - This is also a great way to store fun things for me to lookup later