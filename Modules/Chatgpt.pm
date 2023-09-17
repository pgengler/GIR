package Modules::chatgpt;
use strict;
use OpenAI::API::Request::Chat;

my $chatprompt = 'You are a helpful but extremely concise question answerer. Your output must be no more than 3 brief sentences, preferably fewer. Pack information densely into the answer. Never apologize or use weasel words. If you are unable to answer, or your answer would have to contain an apology, reply instead with the exact string "DOES NOT COMPUTE". Do not ever give any output other than the answer to the asked question.';

sub register
{
        GIR::Modules->register_action('gpt', \&Modules::DNS::answer);
        GIR::Modules->register_help('gpt', \&Modules::DNS::help);
}

sub answer
{
    my $message = shift;
    my $query = $message->message;

    my $chat = OpenAI::API::Request::Chat->new(
        messages => [
            { role => 'system', content => $chatprompt },
            { role => 'user', content => $query },
        ],
        model => "gpt-4"
        );

    my $res = $chat->send();
    return "$res";
}

sub help
{
    my $message = shift;
    return "'gpt <your text>': Asks GPT4 for a concise, helpful response.";
}

1;