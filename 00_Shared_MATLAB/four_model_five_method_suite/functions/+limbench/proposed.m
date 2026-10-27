function [r,h,q]=proposed(m,c)
% PROPOSED Public reusable entry point for the frozen adaptive-angle method.
if nargin<2, c=limbench.defaults(); end
[r,h,q]=limbench.run('proposed_method',m,c);
end
