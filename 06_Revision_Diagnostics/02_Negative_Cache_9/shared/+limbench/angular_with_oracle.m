function [result,history,queries]=angular_with_oracle(model,cfg,oracle)
% Public injection point for the unchanged adaptive 2D angular engine.
% No model-specific classifier or energy function is called here.
[result,history,queries]=angular_engine('angular_improved',model,cfg,oracle,tic);
end
