[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3881974.svg)](https://doi.org/10.5281/zenodo.3881974)

# Pond Trade model: Didactic progressive development of an Agent-based model in NetLogo

This is an Agent-based model (ABM) created explicitly for exemplifying several aspects of the development of ABM models. The target public is students and researchers of Archaeology and History. The development process is broken down into several steps that are progressively complex, each introducing a new concept and NetLogo functionalities. Each step corresponds to a ".nlogox" file (NetLogo >7.0.0) included in this repository. Earlier ".nlogo" versions are kept for archiving purposes, but have not been updated.

For a full description of the model and step-by-step instructions, consult the corresponding chapters in:

Angourakis, Andreas. (2025) 2025. CoDArchLab-ABM/Course-Guide. NetLogo. January 21; Agent-based modelling for archaeologists. From concept to application and publication, released March 31. https://github.com/CoDArchLab-ABM/course-guide.

## List of files and their description:

- **HelloWorld.nlogo**: A simple "Hello World" model to test NetLogo installation and basic functionality.
- **PondTrade_step00_blue circle.nlogox**: a very simple procedure to create a blue circle.
- **PondTrade_step01_replacing magic numbers.nlogox**: the introduction of variables to replace magic numbers.
- **PondTrade_step02_refactoring.nlogox**: firt refactoring of the code.
- **PondTrade_step03_adding noise.nlogox**: adding noise to border of the circle ("coastline").
- **PondTrade_step04_design alternatives and iterations and printing.nlogox**: managing alternative types of noise to border of the circle ("coastline"), using iterators to repeat procedures, and printing messages to the console.
- **PondTrade_step05_refactoring and organizing code.nlogox**: a second refactoring of the code, organizing it into procedures.
- **PondTrade_step06_agent types.nlogox**: adding agents to the model.
- **PondTrade_step07_agent AI v1_links.nlogox**: adding inteligent behaviour to agents (version 1: using links to represent trade routes).
- **PondTrade_step07_agent AI v2_AStar.nlogox**: adding inteligent behaviour to agents (version 2: using A* algorithm to calculate least-cost trade routes).
- **PondTrade_step08_adding feedback loops 1.nlogox**: adding the effect of trade on settlement size, positively related to attractiveness to traders. Settlement size is also subject to a decay process.
- **PondTrade_step09_adding feedback loops 2.nlogox**: adding the effect of trade on settlement potential for traders, positively related to trade. Settlements produce stocks of trade goods in proportion to their size, and stocks are also subject to decay. Trade goods are loaded and unloaded at settlements, and their amount is added to the settlement's size.
- **PondTrade_step10_cultural vectors.nlogox**: adding cultural vectors to the model (neutral traits), allowing for cultural transmission between settlements.
- **PondTrade_step11_trait selection.nlogox**: adding traits that are functional and subject to selection at the settlement level, allowing for cultural evolution.
- **PondTrade_step12_interface statistics.nlogox**: adding statistics and data visualisation to the interface.
- **PondTrade_step13_output statistics.nlogox**: adding aggreated output statistics to the model.
- **PondTrade_step14_submodelled.nlogox**: conversion to a submodelled version of the model, moving the code into separate .nls files and using the `__includes` command to include them in the main model.
