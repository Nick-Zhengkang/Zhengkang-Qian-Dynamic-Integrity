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
function genda_A_worker(c)
genda_A_activate(c);
if c.options.useParallel, maxNumCompThreads(1); end
old=rng; cleanup=onCleanup(@() rng(old));
rng(987650,'twister');
cfg=original_A_adapter('config',c.base); cfg.number_of_steps=2;
result=original_A_adapter('execute',cfg,c.base);
assert(result.success,'Native warm-up failed: %s',result.error_message);
end
