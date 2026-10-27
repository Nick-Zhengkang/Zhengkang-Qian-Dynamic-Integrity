# Declaration of AI Assistance and Author Contributions

## Scope of AI assistance

Generative AI was used extensively for code interpretation and implementation in this thesis. It first assisted with a line-by-line examination of Habib's original DynIn source code, explaining the roles of individual functions, the flow of the algorithm, parameter meanings, trajectory-classification rules, and LIM updates. This assistance concerned the interpretation of existing third-party code; it did not constitute authorship of the original DynIn method.

The new experimental code was written by AI in response to my instructions. For the proposed adaptive angular-radial method, I supplied the methodological ideas and intended behaviour, while AI translated these ideas into the concrete algorithmic implementation. AI assistance therefore extended beyond code completion or language editing.

## My contribution to the experimental design

Before requesting code, I developed the experimental concepts and specified the questions that the implementations were intended to investigate. My role was to determine the purpose of each study, the aspects of the numerical method to examine or improve, and the comparisons needed to assess the proposed changes.

For Experiment A, my objective was to examine how DynIn's numerical and search settings influence the returned LIM, classification behaviour, and computational cost. The intended investigation was not simply to increase resolution or computational effort, but to identify which settings require particular attention and which apparent refinements do not necessarily improve the estimate.

For Experiment B, my objective was to investigate systematic parameter selection using an analytical reference. The intended direction was to obtain a configuration that performs usefully across damping values, and to assess its behaviour beyond the conditions used for selection, including transfer to another model. Accuracy, computational cost, and remaining failure cases were separate aspects of this assessment.

For Experiment C, my objective was to develop a parameter-selection procedure guided by model characteristics and diagnostic trajectories, without using a reference LIM as the tuning objective. I specified the need to connect physical information with numerical settings and to investigate classification-related issues, including integration time and computational-domain coverage, before interpreting the effects of additional search effort.

For the two-method comparison, my objective was to assess the proposed search method against original DynIn GA across several models, considering estimation accuracy where an independent reference was available, variability between runs, and computational cost. These objectives defined the intended direction of the experiments; they did not predetermine which method should perform better.

## My contribution to the proposed method

For the proposed method, I provided the idea of separating disturbance direction from disturbance magnitude and using radial queries to investigate the transition between target and non-target classifications. I directed the development towards adaptive direction selection, including local directional refinement and exploration of insufficiently sampled angular regions. AI was responsible for expressing these ideas in executable code, including the supporting functions and their integration into the experimental workflow.

## Review and iterative revision

I carefully reviewed the generated code line by line. After trial runs, I examined whether the implemented behaviour matched the intended experimental design. When I identified a mismatch, I provided specific modification requests, and the revised implementation was reviewed and tested again. This iterative process involved my assessment and direction rather than unconditional acceptance of AI-generated output.

My review and testing do not, by themselves, establish the mathematical correctness of the algorithms or the validity of every numerical result. I remain responsible for the submitted code, its documentation, and the scientific claims based on its outputs. The AI-assisted scope is identified in the relevant code comments and accompanying usage records.

Author: Zhengkang Qian
Declaration text approved by the author on 27 October 2026.
