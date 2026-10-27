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
function bayes8_worker_init(c)
% The client and every worker must resolve exactly the same numerical files.
accuracy_first_activate(c.root,c.shared,c.adapter,c.native,c.model);
if c.options.useParallel, maxNumCompThreads(1); end
if ~c.options.synthetic
    keep=rng; cleanup=onCleanup(@() rng(keep));
    rng(987650,'twister');
    cfg=bayes8_design('config',c.bx,c.base); cfg.number_of_steps=2;
    result=original_A_adapter('execute',cfg,c.base);
    assert(result.success,'Worker warm-up failed: %s',result.error_message);
end
end
