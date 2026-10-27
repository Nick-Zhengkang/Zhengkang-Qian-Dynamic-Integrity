% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
function o=top6_options(mode)
% Complete six-factor grid; three NEW paired seeds for exploratory ranking.
if nargin<1, mode='full'; end
o.mode=validatestring(mode,{'full','smoke'});
o.seeds=4101:4103;
o.kValues=[1 3 5 7 9 11];
o.gridValues=[351 551 701 901 1051];
o.generationValues=[2 3 5 10];
o.newcomerRatioValues=[0.2 0.4 0.6];
o.populationValues=[10 15 20];
o.selectedValues=[2 3 5];
o.scheduleSeed=12102026;
o.diagnosticAngles=24;
o.exportEvery=25;
o.longRunWarningSeconds=120;
o.errorThreshold=0.01;
o.medianErrorMargin=0;
o.p95ErrorMargin=0;
o.passRateLoss=0;
o.falseSafeMargin=0;
o.falseUnsafeMargin=0;
o.maxMeanFalseSafe=0.01;
o.maxDiagnosticUnresolved=0;
if strcmp(o.mode,'smoke')
    o.seeds=4101;
    o.diagnosticAngles=4;
    o.exportEvery=1;
end
end
